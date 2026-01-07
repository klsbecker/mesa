#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'

$ts = get_test_setup("mesa_pc_b2b_2x")

# Policer test table
test_table =
[
    {
        txt: "Policer disabled",
        cfg: {idx: 0, rate: 0xffffffff},
        chk: {ig: [0], eg: 1, etolerance: [2]}
    },
    {
        txt: "Policer bit rate 100 kbps",
        cfg: {idx: 0, rate: 100},
        chk: {ig: [0], eg: 1, sec: 5, erate: [100000], etolerance: [6], with_pre_tx: true}
    },
    {
        txt: "Policer bit rate 1000 kbps",
        cfg: {idx: 0, rate: 1000},
        chk: {ig: [0], eg: 1, sec: 3, erate: [1000000], etolerance: [3]}
    },
    {
        txt: "Policer bit rate 10000 kbps",
        cfg: {idx: 0, rate: 10000},
        chk: {ig: [0], eg: 1, erate: [10000000], etolerance: [2]}
    },
    {
        txt: "Policer bit rate 100000 kbps",
        cfg: {idx: 0, level: 1, rate: 100000},
        chk: {ig: [0], eg: 1, erate: [100000000], etolerance: [2]}
    },
    {
        txt: "Policer bit rate 1000000 kbps",
        cfg: {idx: 0, level: 1, rate: 1000000},
        chk: {ig: [0], eg: 1, erate: [1000000000], etolerance: [2]}
    },
    {
        txt: "Policer frame rate 100 fps",
        cfg: {idx: 0, frame_rate: true, rate: 100},
        chk: {ig: [0], eg: 1, sec: 3, frame_rate: true, erate: [100], etolerance: [2], with_pre_tx: true}
    },
    {
        txt: "Policer frame rate 1000 fps",
        cfg: {idx: 0, frame_rate: true, rate: 1000},
        chk: {ig: [0], eg: 1, sec: 2, frame_rate: true, erate: [1000], with_pre_tx: true}
    },
    {
        txt: "Policer frame rate 10000 fps",
        cfg: {idx: 0, frame_rate: true, level: 206, rate: 10000},
        chk: {ig: [0], eg: 1, frame_rate: true, erate: [10000], with_pre_tx: true}
    },
    {
        txt: "Policer frame rate 100000 fps",
        cfg: {idx: 0, frame_rate: true, level: 206, rate: 100000},
        chk: {ig: [0], eg: 1, frame_rate: true, erate: [100000], etolerance: [2]}
    }
]

# Policer test function
def policer_test(t)
    cfg = fld_get(t, :cfg)
    chk = fld_get(t, :chk)

    # Get number of policers
    pol_cnt = $ts.dut.call("mesa_capability", "MESA_CAP_QOS_PORT_POLICER_CNT")

    # Configure port policer
    port = $ts.dut.p[cfg[:idx]]
    c = $ts.dut.call("mesa_qos_port_policer_conf_get", port, pol_cnt)
    pol = c[0]
    pol["frame_rate"] = fld_get(cfg, :frame_rate, false)
    pol["policer"]["level"] = fld_get(cfg, :level)
    pol["policer"]["rate"] = cfg[:rate]
    $ts.dut.call("mesa_qos_port_policer_conf_set", port, pol_cnt, c)

    # Test policer rate
    chk[:size] = 1000
    check_rate(chk)
end

# Run all or selected test
sel = table_lookup(test_table, :sel)
test_table.each do |t|
    test t[:txt] do
        next if (t[:sel] != sel)
        policer_test(t)
    end
end

test_summary

test "dump" do
    #$ts.dut.run("mesa-cmd deb api ai qos")
end

exit