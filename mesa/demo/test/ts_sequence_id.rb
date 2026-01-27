#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'
require_relative 'ts_lib'

$ts = get_test_setup("mesa_pc_b2b_2x")

$port0 = 0
$npi_port = 1
#$port1 = 2
$cpu_queue = 7

cfg = { cap_array: ["PACKET_TX_IFH_SIZE", "PACKET_IFH_EPID"] }
cap_check_ts(cfg)

def tod_sequence_id_test(sec_cntr)
    test "tod_sequence_id_test  #{sec_cntr}" do

    sequence = $ts.dut.call("mesa_ts_seq_cnt_get", sec_cntr)    # Get the sequence number indicated by the lowest byte of the timestamp

    frameHdrTx = frame_create("00:02:03:04:05:06", "00:08:09:0a:0b:0c")

    t_i "Transmit a SYNC frame without sequence number update into NPI port with frame check"
    $tod_ts  = $ts.dut.call("mesa_ts_timeofday_get")
    $tod_ts[0]["seconds"] = 9
    $tod_ts[0]["nanoseconds"] = 0
    $ts.dut.call("mesa_ts_timeofday_set", $tod_ts[0])

    frametx = tx_ifh_create($ts.dut.port_list[$port0], "MESA_PACKET_PTP_ACTION_ORIGIN_TIMESTAMP") + frameHdrTx.dup + sync_pdu_create()
    framerx = frameHdrTx.dup + sync_pdu_rx_create(IGNORE, 9, IGNORE, IGNORE, true)
    frame_cfg = { frame: frametx, port: $npi_port, frame0: framerx, port0: $port0, port1: nil, npi_port: $npi_port }
    frame_tx(frame_cfg)

    t_i "Transmit a SYNC frame into NPI port with no frame check"
    frametx = tx_ifh_create($ts.dut.port_list[$port0], "MESA_PACKET_PTP_ACTION_ORIGIN_TIMESTAMP_SEQ", sec_cntr<<16, 0, sec_cntr) +
              frameHdrTx.dup + sync_pdu_create(0, sec_cntr)
    frame_cfg = { frame: frametx, port: $npi_port, port0: $port0, port1: nil, npi_port: $npi_port }
    frame_tx(frame_cfg)

    test "Inject SYNC frame into NPI port with MESA_PACKET_PTP_ACTION_ORIGIN_TIMESTAMP_SEQ and check the sequence id" do
    framerx = frameHdrTx.dup + sync_pdu_rx_create(IGNORE, IGNORE, (sequence + 1))
    frame_cfg = { frame: frametx, port: $npi_port, frame0: framerx, port0: $port0, port1: nil, npi_port: $npi_port }
    frame_tx(frame_cfg)

    conf = $ts.dut.call("mesa_ts_seq_cnt_get", sec_cntr)    # Get the sequence number indicated by the lowest byte of the timestamp
    if (conf != (sequence + 2))
        t_e("Sequence number is not as expected.  sequence number = #{conf}  expected = #{sequence+2}")
    end
    end

    test "Inject SYNC frame into NPI port with MESA_PACKET_PTP_ACTION_AFI_NONE and check the sequence id" do
    frametx = tx_ifh_create($ts.dut.port_list[$port0], "MESA_PACKET_PTP_ACTION_AFI_NONE", sec_cntr<<16, 0, sec_cntr) +
              frameHdrTx.dup + sync_pdu_create(0, sec_cntr)
    framerx = frameHdrTx.dup + sync_pdu_rx_create(IGNORE, IGNORE, (sequence + 2), 0)
    frame_cfg = { frame: frametx, port: $npi_port, frame0: framerx, port0: $port0, port1: nil, npi_port: $npi_port }
    frame_tx(frame_cfg)

    conf = $ts.dut.call("mesa_ts_seq_cnt_get", sec_cntr)    # Get the sequence number indicated by the lowest byte of the timestamp
    if (conf != (sequence + 3))
        t_e("Sequence number is not as expected.  sequence number = #{conf}  expected = #{sequence+2}")
    end
    end
    end
end


test "test_conf" do
    # disable VLAN 1 to avoid looping
    $ts.dut.call("mesa_vlan_port_members_set", 1, "")

    # CPU queue configuration
    $packet_rx_conf_restore = $ts.dut.call("mesa_packet_rx_conf_get")
    conf = $packet_rx_conf_restore.dup
    conf["queue"][$cpu_queue]["npi"]["enable"] = true
    $ts.dut.call("mesa_packet_rx_conf_set", conf)

    # NPI port configuration save
    $npi_conf_restore = $ts.dut.call("mesa_npi_conf_get")
    conf = $npi_conf_restore.dup
    conf["enable"] = true
    conf["port_no"] = $ts.dut.port_list[$npi_port]
    $ts.dut.call("mesa_npi_conf_set", conf)

    $ts.pc.p.each_index do |i|
        $ts.pc.run("sudo ip link set dev #{$ts.pc.p[i]} up")
        $ts.pc.run("sudo sysctl -w net.ipv6.conf.#{$ts.pc.p[i]}.disable_ipv6=1")
    end
end

test "test_run" do
    # Test TOD sequence ID increment
    sec_cntr = 0x55
    if (cap_get("MISC_CHIP_FAMILY") == chip_family_to_id("MESA_CHIP_FAMILY_LAN966X"))
        sec_cntr = 3
    end

    tod_sequence_id_test(sec_cntr)

    sec_cntr = 0x77
    if (cap_get("MISC_CHIP_FAMILY") == chip_family_to_id("MESA_CHIP_FAMILY_LAN966X"))
        sec_cntr = 6
    end

    tod_sequence_id_test(sec_cntr)
end

test "test_clean_up" do
    # CPU queue configuration restore
    $ts.dut.call("mesa_packet_rx_conf_set", $packet_rx_conf_restore)

    # NPI port configuration restore
    $ts.dut.call("mesa_npi_conf_set", $npi_conf_restore)
end

test_summary

test "dump" do
    #$ts.dut.run("mesa-cmd deb api ci ts")
end
