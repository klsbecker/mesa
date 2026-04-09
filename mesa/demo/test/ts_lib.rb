#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'

PTP_REQUEST_MESSAGE = 1
PTP_RESPOND_MESSAGE = 9
IGNORE = 0xFFFFFFFF

def nano_corr_lowest_measure(ip: "", port0:, port1:)
    nano_corr_lowest = 0xFFFFFFFFFFFFFFFF
    nano_corr_highest = 0
    range = 0

    t_i("nano_corr_lowest_measure")

    # Create the SYNC frame
    if (ip != "")
        size = 44+28+17
        off = 14+28
        if (ip == "ipv6")
            size += 20
            off += 20
        end
        frametx = frame_create("01:80:C2:00:00:30", "00:00:00:00:05:07", "#{ip} udp") + sync_pdu_create(0)
    else
        size = 40
        off = 14
        frametx = frame_create("01:80:C2:00:00:30", "00:00:00:00:05:07") + sync_pdu_create(0)
    end

    for i in 0..5
        # Transmit SYNC frame into port0
        frame_cfg = { frame: frametx, port: port0, frame0: false, capture_size: size, port0: port0, port1: port1, npi_port: nil }
        frame_tx(frame_cfg)
        pkts = $ts.pc.get_pcap "#{$ts.links[port1][:pc]}.pcap"
        data = pkts[0][:data].each_byte.map{|c| c.to_i}

        # Calculate the lowest correction value based on frame timestamp
        nano_correction = ((data[off+8]<<40) + (data[off+9]<<32) + (data[off+10]<<24) + (data[off+11]<<16) + (data[off+12]<<8) + (data[off+13]))
        if (nano_correction < nano_corr_lowest)
            nano_corr_lowest = nano_correction
        end
        if (nano_correction > nano_corr_highest)
            nano_corr_highest = nano_correction
        end
    end
    range = nano_corr_highest-nano_corr_lowest

    t_i("nano_corr_lowest = #{nano_corr_lowest}")
    t_i("nano_corr_highest = #{nano_corr_highest}")
    t_i("range = #{range}")

    return nano_corr_lowest, range
end

def tc_to_tod_nano(tc, tod)
    tod_nano_ret = 0

    if (cap_get("MISC_CHIP_FAMILY") == chip_family_to_id("MESA_CHIP_FAMILY_JAGUAR2"))
        tc = tc >> 16
        t_i("tc_to_tod_nano: tc = #{tc}")
    
        tod_tc = (tod[1] >> 16)
        if (tod_tc > tc)
            t_i("tc has wrapped. tc #{tc}  tod_tc #{tod_tc}  diff #{tod_tc - tc}")
            tc += 0xFFFFFFFF    # Add 0xFFFFFFFF to tc
        end
        diff_tc = tc - tod_tc
        diff_ns = diff_tc % 1000000000
        tod_ns = tod[0]["nanoseconds"] + diff_ns
        tod_nano_ret = tod_ns % 1000000000
        t_i("diff_tc #{diff_tc}  diff_ns #{diff_ns}  tod_ns #{tod_ns}  tod_nano_ret #{tod_nano_ret}")
    end

    return tod_nano_ret << 16
end

def frame_tx(cfg)
    frame = cfg[:frame]
    port = cfg[:port]
    frame0 = fld_get(cfg, :frame0, nil)
    frame1 = fld_get(cfg, :frame1, nil)
    framenpi = fld_get(cfg, :framenpi, nil)
    capture_size = fld_get(cfg, :capture_size, 0)
    port0 = cfg[:port0]
    port1 = cfg[:port1]
    npi_port = cfg[:npi_port]

    if (capture_size != 0)
        cap = $ts.links.collect{|x| "-c #{x[:pc]},#{capture_size},adapter_unsynced,,20"}.join(" ")
        cmd = "ef #{cap} name ftx #{frame}"
    else
        cmd = "ef name ftx #{frame}"
    end

    {frx0: frame0, frx1: frame1, frxn: framenpi}
    .each do |name, f|
        cmd += "name #{name} #{f}" if f.is_a?(String)
    end

    cmd += "tx #{$ts.pc.p[port]} name ftx "

    [[frame0, port0, "frx0"],
    [frame1, port1, "frx1"],
    [framenpi, npi_port, "frxn"]]
    .each do |f, p, name|
        next if (f.nil? || p.nil?)  # skip check entirely
        
        port_value = $ts.pc.p[p]

        if (f == false)             # expect no frame
            cmd += "rx #{port_value} "
        else                        # expect specific frame
            cmd += "rx #{port_value} name #{name} "
        end
    end

    $ts.pc.try_with_stderr_as_info cmd
end

def rx_ifh_extract(frame)
    data = frame[:data].each_byte.map{|c| c.to_i}

    ifh = data[16..16+36]
    for i in 37..39
        ifh << 0
    end

    return ifh
end

# tx_ifh_create: Be careful when adding here as it can affect time-sensitive tests like ts_sequence_id.rb, Calls that take long time should be avoided.
def tx_ifh_create(port=0, ptp_act="MESA_PACKET_PTP_ACTION_ORIGIN_TIMESTAMP_SEQ", ptp_ts=0xFEFEFEFE0000, domain=0, seq_idx=0, proto="")
    t_i("tx_ifh_create.  port = #{port}  ptp_act = #{ptp_act}  ptp_ts #{ptp_ts}  domain #{domain}  seq_idx #{seq_idx} proto #{proto}")

    tx_info = {
        "dst_port" => port,
        "switch_frm" => false,
        "masquerade_port" => 0xFFFFFFFF,
        "pdu_offset" => 14,
        "sequence_idx" => seq_idx,
        "ptp_action" => ptp_act,
        "ptp_domain" => domain,
        "ptp_timestamp" => ptp_ts,
        "inj_encap" => {
            "type" => case proto
                when "ipv4" then "MESA_PACKET_ENCAP_TYPE_IP4"
                when "ipv6" then "MESA_PACKET_ENCAP_TYPE_IP6"
                else "MESA_PACKET_ENCAP_TYPE_NONE"
            end,
            "tag_count" => 0
        }
    }
        
    return cmd_tx_ifh_push(tx_info)
end

def rx_ifh_create(port=IGNORE)
    cmd = cmd_rx_ifh_push({ port: port })
    return cmd
end

def frame_create(dmac, smac, proto="")
    frame = ""

    t_i("frame_create.  dmac = #{dmac}  smac = #{smac}  proto #{proto}")

    if (proto == "")
        frame = "eth dmac #{dmac} smac #{smac} et 0x88F7 "
    else
        frame = "eth dmac #{dmac} smac #{smac} #{proto} "
    end

    return frame
end

def sync_pdu_create(header_rsv=0, hdr_sequenceId=0)
    sync_pdu = ""

    t_i("sync_pdu_create header_rsv #{header_rsv}")

    sync_pdu = "ptp-sync hdr-reserved2 #{header_rsv} hdr-sequenceId #{hdr_sequenceId} data repeat 2 0x00 "

    return sync_pdu
end

def sync_pdu_rx_create(header_rsv=IGNORE, secondsField=IGNORE, sequenceId=IGNORE, cf_org=IGNORE, all=false)
    sync_pdu = ""

    t_i("sync_pdu_rx_create  header_rsv #{header_rsv} secondsField #{secondsField}")

    sync_pdu = "ptp-sync ign "

    if (all)
        sync_pdu = "ptp-sync ign "
        sync_pdu += "hdr-transportSpecific 0 "
        sync_pdu += "hdr-messageType 0 "
        sync_pdu += "hdr-minorVersionPTP 0 "
        sync_pdu += "hdr-versionPTP 0 "
        sync_pdu += "hdr-messageLength 46 "
        sync_pdu += "hdr-domainNumber 0 "
        sync_pdu += "hdr-reserved1 0 "
        sync_pdu += "hdr-flagField 0 "
        sync_pdu += "hdr-reserved2 0 "
        sync_pdu += "hdr-clockId 0 "
        sync_pdu += "hdr-portNumber 0 "
        sync_pdu += "hdr-controlField 0 "
        sync_pdu += "hdr-logMessageInterval 0 "
    end

    if (header_rsv != IGNORE)
        sync_pdu += "hdr-reserved2 #{header_rsv} "
    end
    if (sequenceId != IGNORE)
        sync_pdu += "hdr-sequenceId #{sequenceId} "
    end
    if (secondsField != IGNORE)
        sync_pdu += "ots-secondsField #{secondsField} "
    end
    if (cf_org != IGNORE)
        sync_pdu += "hdr-correctionField 0 ots-secondsField 0 ots-nanosecondsField 0 "
    end
    sync_pdu += "data repeat 2 0x00 "

    return sync_pdu
end

def request_pdu_create(requestClockId, requestPortNumber)
    request_pdu = ""

    t_i("request_pdu_create requestClockId #{requestClockId} requestPortNumber #{requestPortNumber}")

    request_pdu = "ptp-request hdr-clockId #{requestClockId} hdr-portNumber #{requestPortNumber} data repeat 2 0x00 "

    return request_pdu
end

def response_pdu_rx_create(controlField=IGNORE, secondsField=IGNORE, reqClockId=IGNORE, srcClockId=IGNORE, reqPortNumber=IGNORE, srcPortNumber=IGNORE, flagField=IGNORE)
    response_pdu = ""

    t_i("response_pdu_rx_create requestClockId #{controlField} #{controlField} secondsField #{secondsField} reqClockId #{reqClockId} srcClockId #{srcClockId} reqPortNumber #{reqPortNumber} srcPortNumber #{srcPortNumber} flagField #{flagField}")

    response_pdu = "ptp-response ign hdr-messageType #{PTP_RESPOND_MESSAGE} "
    if (flagField != IGNORE)
        response_pdu += "hdr-flagField #{flagField} "
    end
    if (srcClockId != IGNORE)
        response_pdu += "hdr-clockId #{srcClockId} "
    end
    if (srcPortNumber != IGNORE)
        response_pdu += "hdr-portNumber #{srcPortNumber} "
    end
    if (controlField != IGNORE)
        response_pdu += "hdr-controlField #{controlField} "
    end
    if (secondsField != IGNORE)
        response_pdu += "rts-secondsField #{secondsField} "
    end
    if (reqClockId != IGNORE)
        response_pdu += "rpi-clockId #{reqClockId} "
    end
    if (reqPortNumber != IGNORE)
        response_pdu += "rpi-portNumber #{reqPortNumber} "
    end

    if ((cap_get("MISC_CHIP_FAMILY") == chip_family_to_id("MESA_CHIP_FAMILY_JAGUAR2")) ||
        (cap_get("MISC_CHIP_FAMILY") == chip_family_to_id("MESA_CHIP_FAMILY_SPARX5")))
        response_pdu += "data repeat 2 0 "
    end

    return response_pdu
end

def cap_check_ts(cfg = {})
    cap_array = fld_get(cfg, :cap_array, [])
    ext_clk_loop = fld_get(cfg, :ext_clk_loop, false)
    ext_rs422_clk_loop = fld_get(cfg, :ext_rs422_clk_loop, false)
    skip_on_fpga = fld_get(cfg, :skip_on_fpga, false)
    skipped_families = fld_get(cfg, :skipped_families, [
        "MESA_CHIP_FAMILY_CARACAL", "MESA_CHIP_FAMILY_SERVAL", "MESA_CHIP_FAMILY_SERVALT", "MESA_CHIP_FAMILY_OCELOT"])

    check_capabilities() do
        tslib_assert_supported_chip(cap_get("MISC_CHIP_FAMILY"), skipped_families)
        cap_check_exit("TS")

        assert($ts.ts_external_clock_looped == true, "External clock must be looped") if ext_clk_loop
        assert(($ts.ts_rs422 == true), "External RS422 clock must be looped") if ext_rs422_clk_loop
        assert(cap_get("MISC_FPGA") == 0, "FPGA is not supported") if skip_on_fpga
    end
    
    cap_array.each do |cap|
        t_i("Checking capability for #{cap}")
        cap_check_exit(cap)
    end
end

# Generic function to check supported chip families in the timestamping tests
def tslib_assert_supported_chip(chip_family_id, unsupported_array)
    chip_family = chip_id_to_family(chip_family_id)

    if unsupported_array.include?(chip_family)
        assert(false, "#{chip_family} is not supported in this test")
    end
end
