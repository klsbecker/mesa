#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'

$ts = get_test_setup("mesa_pc_b2b_2x")

cap_check_exit("QOS_GLOBAL_STORM_FRAME_RATE_MAX")

$ig_port = 0

test "Baseline: storm should be 0 when all storm policers are disabled" do
    conf = $ts.dut.call("mesa_qos_conf_get")

    ["policer_uc", "policer_mc", "policer_bc"].each do |p|
        conf[p]["rate"] = 0xFFFFFFFF
        conf[p]["frame_rate"] = true
        conf[p]["mode"] = "MESA_STORM_POLICER_MODE_PORTS_AND_CPU"
    end
    $ts.dut.call("mesa_qos_conf_set", conf)

    $ts.dut.call("mesa_qos_status_get") # Clear leftover stickies

    storm = $ts.dut.call("mesa_qos_status_get")["storm"]
    t_e("Baseline: expected storm = 0, got #{storm}") if (storm != 0)
end

test "Enable mc policer at 100000 fps, send a tiny burst well below rate" do
    conf = $ts.dut.call("mesa_qos_conf_get")
    conf["policer_mc"]["rate"] = 100000
    conf["policer_mc"]["frame_rate"] = true
    conf["policer_mc"]["mode"] = "MESA_STORM_POLICER_MODE_PORTS_ONLY"
    $ts.dut.call("mesa_qos_conf_set", conf)

    $ts.dut.call("mesa_qos_status_get") # Clear any leftover stickies

    # Send 20 multicast frames, far below 100000 fps, so no frames should be dropped by the storm policer.
    t_i("Send 20 multicast frames (no storm expected)")
    tx_cnt = 20
    cmd = "sudo ef name f1 eth dmac 01:00:5E:05:06:07 smac 00:00:00:00:00:0a data pattern cnt 40 "
    cmd += "tx #{$ts.pc.p[$ig_port]} rep #{tx_cnt} name f1"
    $ts.pc.run(cmd)

    sleep(1)

    storm = $ts.dut.call("mesa_qos_status_get")["storm"]
    if (storm != 0)
        t_e("Storm reported #{storm} on #{tx_cnt}-frame burst well below 100000 fps")
    else
        t_i("PASS: storm = #{storm} on traffic below rate")
    end
end

# $ts.dut.run("mesa-cmd deb api ai qos") # Dump

test_summary()
