#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'

$ts = get_test_setup("mesa_pc_b2b_2x")

################################################
# Capability Check and Globals
################################################

cap_check_exit("QOS_GLOBAL_STORM_FRAME_RATE_MAX")

$ig_port = 0
$eg_port = 1

NO_STICKY_FAMILIES = [
    chip_family_to_id("MESA_CHIP_FAMILY_CARACAL"), # Drops only
    chip_family_to_id("MESA_CHIP_FAMILY_SERVAL"),  # Drops only
    chip_family_to_id("MESA_CHIP_FAMILY_OCELOT"),  # Drops only
    chip_family_to_id("MESA_CHIP_FAMILY_LAN966X"), # Drop counter
    # Families outside this enum are expected to be STICKY, otherwise add here.
]
$has_active_sticky = !NO_STICKY_FAMILIES.include?(cap_get("MISC_CHIP_FAMILY"))

################################################
# Test Tables
################################################

def policer_type_str(type)
    case type
    when "uc" then "Unicast"
    when "mc" then "Multicast"
    when "bc" then "Broadcast"
    end
end

def with_title(entry)
    cfg = entry[:cfg]
    parts = ["#{policer_type_str(cfg[:policer_type])} policer at rate = #{cfg[:rate]}, burst = #{cfg[:frame_burst]}"]
    entry.merge(txt: parts.join(', '))
end

test_table =
[
    {
        txt: "Storm should be inactive when all storm policers are disabled",
        cfg: {rate: 0xFFFFFFFF},
    },

    # Broadcast
    with_title({
        cfg: {policer_type: "bc", rate: 10, frame_burst: 100},
    }),

    with_title({
        cfg: {policer_type: "bc", rate: 10, frame_burst: 250},
    }),

    with_title({
        cfg: {policer_type: "bc", rate: 10, frame_burst: 1_000},
    }),

    with_title({
        cfg: {policer_type: "bc", rate: 100, frame_burst: 10_000},
    }),

    with_title({
        cfg: {policer_type: "bc", rate: 10_000, frame_burst: 20},
    }),

    # Unicast
    with_title({
        cfg: {policer_type: "uc", rate: 10, frame_burst: 100},
    }),

    with_title({
        cfg: {policer_type: "uc", rate: 10, frame_burst: 250},
    }),

    with_title({
        cfg: {policer_type: "uc", rate: 10, frame_burst: 1_000},
    }),

    with_title({
        cfg: {policer_type: "uc", rate: 100, frame_burst: 10_000},
    }),

    with_title({
        cfg: {policer_type: "uc", rate: 10_000, frame_burst: 20},
    }),

    # Multicast
    with_title({
        cfg: {policer_type: "mc", rate: 10, frame_burst: 100},
    }),

    with_title({
        cfg: {policer_type: "mc", rate: 10, frame_burst: 250},
    }),

    with_title({
        cfg: {policer_type: "mc", rate: 10, frame_burst: 1_000},
    }),

    with_title({
        cfg: {policer_type: "mc", rate: 100, frame_burst: 10_000},
    }),

    with_title({
        cfg: {policer_type: "mc", rate: 10_000, frame_burst: 20},
    }),
]

################################################
# Test Runners
################################################
def test_runner(t)
    cfg = fld_get(t, :cfg)

    rate = fld_get(cfg, :rate, 0)
    frame_burst = fld_get(cfg, :frame_burst, 0)
    cfg[:frame_rate] = fld_get(cfg, :frame_rate, true)

    if (rate == 0xFFFFFFFF)
        basic_storm_policer_disabled_test(cfg)
        return
    end

    storm_with_rate_and_frame_burst(cfg) if(frame_burst > 0)
    clear_storm_every_status_call(cfg) if(($has_active_sticky || (rate < frame_burst)) && (frame_burst > 0))
    ongoing_storm_test(cfg)
end

################################################
# General/Helper Functions
################################################

def ti_mod(msg)
    t_i("\n\n" + msg + "\n")
end

def clear_ig_counters
    $ts.dut.call("mesa_port_counters_clear", $ts.dut.p[$ig_port])
    $ts.dut.call("mesa_port_counters_clear", $ts.dut.p[$eg_port])
end

def report_ig_drops(label)
    ic = $ts.dut.call("mesa_port_counters_get", $ts.dut.p[$ig_port])
    ec = $ts.dut.call("mesa_port_counters_get", $ts.dut.p[$eg_port])
    rx  = ic["rmon"]["rx_etherStatsPkts"]
    tx  = ec["rmon"]["tx_etherStatsPkts"]
    drops = rx - tx
    t_i("#{label}: ig_rx=#{rx} eg_tx=#{tx} dropped=#{drops}")
    return drops
end

def dmac_for(type)
    case type
    when "uc" then "00:11:22:33:44:55" # Unicast
    when "mc" then "01:00:5E:05:06:07" # Multicast
    when "bc" then "FF:FF:FF:FF:FF:FF" # Broadcast
    end
end

def send_frames(type, tx_cnt)
    cmd = "sudo ef name f1 eth dmac #{dmac_for(type)} smac 00:00:00:00:00:0a data pattern cnt 40 "
    cmd += "tx #{$ts.pc.p[$ig_port]} rep #{tx_cnt} name f1"
    $ts.pc.run(cmd)
    sleep(1)
end

def start_storm_bg(type)
    cmd = "sudo ef name f1 eth dmac #{dmac_for(type)} smac 00:00:00:00:00:0a data pattern cnt 40 "
    cmd += "tx #{$ts.pc.p[$ig_port]} rep 10000000 name f1"
    $ts.pc.bg("#{type}-storm", cmd)
end

def stop_storm_bg(pid)
    $ts.pc.run("sudo pkill -f 'ef name f1' || true")
    sleep(1)
    $ts.pc.bg_exitstatus(pid)
end

def basic_storm_policer_disabled_test(cfg)
    conf = $ts.dut.call("mesa_qos_conf_get")

    ["policer_uc", "policer_mc", "policer_bc"].each do |p|
        conf[p]["rate"] = cfg[:rate]
        conf[p]["frame_rate"] = cfg[:frame_rate]
        conf[p]["mode"] = "MESA_STORM_POLICER_MODE_PORTS_ONLY"
    end
    $ts.dut.call("mesa_qos_conf_set", conf)

    $ts.dut.call("mesa_qos_status_get") # Clear leftover storm

    storm = $ts.dut.call("mesa_qos_status_get")["storm"]
    t_e("Expected storm = 0, got #{storm}") if (storm != 0)
end

def storm_with_rate_and_frame_burst(cfg)
    type = cfg[:policer_type]
    rate = cfg[:rate]
    frame_burst = cfg[:frame_burst]

    conf = $ts.dut.call("mesa_qos_conf_get")
    conf["policer_#{type}"]["rate"] = rate
    conf["policer_#{type}"]["frame_rate"] = cfg[:frame_rate]
    conf["policer_#{type}"]["mode"] = "MESA_STORM_POLICER_MODE_PORTS_ONLY"
    $ts.dut.call("mesa_qos_conf_set", conf)

    $ts.dut.call("mesa_qos_status_get") # Clear any leftover storm
    clear_ig_counters()

    t_i("Send #{frame_burst} #{type.upcase} frames")
    send_frames(type, frame_burst)
    drops = report_ig_drops("Test: rate = #{rate} After burst of #{frame_burst}")
    t_e("Reported #{drops} drops, but expected more drops when rate = #{rate} and burst = #{frame_burst}") if (rate < frame_burst && drops <= rate)

    storm = $ts.dut.call("mesa_qos_status_get")["storm"]
    if ($has_active_sticky)
        t_e("Storm reported #{storm}, but drops have occurred") if (storm == 0 && drops != 0)
    else
        t_e("Storm reported #{storm} but no drops occurred") if (storm != 0 && drops == 0)
    end
end

def clear_storm_every_status_call(cfg)
    type = cfg[:policer_type]
    rate = cfg[:rate]
    frame_burst = cfg[:frame_burst]

    conf = $ts.dut.call("mesa_qos_conf_get")
    conf["policer_#{type}"]["rate"] = rate
    conf["policer_#{type}"]["frame_rate"] = cfg[:frame_rate]
    conf["policer_#{type}"]["mode"] = "MESA_STORM_POLICER_MODE_PORTS_ONLY"
    $ts.dut.call("mesa_qos_conf_set", conf)

    ti_mod("Clear storm status")
    $ts.dut.call("mesa_qos_status_get")
    clear_ig_counters()

    ti_mod("Activate a #{type.upcase} storm")
    send_frames(type, frame_burst)

    ti_mod("Get status during a storm, expect storm to be active")
    storm = $ts.dut.call("mesa_qos_status_get")["storm"] # Get and clear storm

    if (rate > frame_burst)
        t_e("After activation: Expected no storm, but received a storm") if (storm != 0)
    else
        t_e("After activation: Expected a storm, but no storm received") if (storm != 1)
    end

    ti_mod("End the storm")
    send_frames(type, frame_burst)

    ti_mod("Expect storm active after storm since no clear inbetween")
    storm = $ts.dut.call("mesa_qos_status_get")["storm"] # Get and clear storm
    
    if (rate > frame_burst)
        t_e("After activation: Expected no storm, but received a storm") if (storm != 0)
    else
        t_e("After activation: Expected a storm, but no storm received") if (storm != 1)
    end

    ti_mod("No storm since last clear, therefore expect no storm from get status")
    storm = $ts.dut.call("mesa_qos_status_get")["storm"]
    t_e("After settle: expected storm = 0, got #{storm}") if (storm != 0)
end

def ongoing_storm_test(cfg)
    type = cfg[:policer_type]

    conf = $ts.dut.call("mesa_qos_conf_get")
    conf["policer_#{type}"]["rate"] = cfg[:rate]
    conf["policer_#{type}"]["frame_rate"] = cfg[:frame_rate]
    conf["policer_#{type}"]["mode"] = "MESA_STORM_POLICER_MODE_PORTS_ONLY"
    $ts.dut.call("mesa_qos_conf_set", conf)

    ti_mod("Clear storm status")
    $ts.dut.call("mesa_qos_status_get")

    ti_mod("Start a continuous #{type.upcase} storm in the background")
    pid = start_storm_bg(type)
    sleep(1) # let drops accumulate

    ti_mod("Get status during ongoing storm (clears storm, reports storm active)")
    storm = $ts.dut.call("mesa_qos_status_get")["storm"]
    t_e("During storm: expected storm = 1, got #{storm}") if (storm != 1)

    ti_mod("Get status 'without clearing': Storm is still ongoing, so bits are set again")
    sleep(1)
    storm = $ts.dut.call("mesa_qos_status_get")["storm"]
    t_e("Still-ongoing storm: expected storm = 1, got #{storm}") if (storm != 1)

    ti_mod("Stop the storm")
    stop_storm_bg(pid)

    ti_mod("Drain residual drops")
    sleep(1)
    $ts.dut.call("mesa_qos_status_get")

    ti_mod("No new traffic after stop, expect no storm")
    storm = $ts.dut.call("mesa_qos_status_get")["storm"]
    t_e("After stop, expected storm = 0, got #{storm}") if (storm != 0)
end

################################################
# Test Section
################################################

sel = table_lookup(test_table, :sel)
test_table.each do |t|
    next if (t[:sel] != sel)
    test t[:txt] do
        test_runner(t)
    end
end

################################################
# Test Dump & Summary
################################################

# $ts.dut.run("mesa-cmd deb api ai qos 5") # QOS Storm Policing

test_summary()
