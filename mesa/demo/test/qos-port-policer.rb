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
        cfg: {rate: 0xffffffff},
        chk: {etolerance: [2]}
    },
    {
        txt: "Policer bit rate 100 kbps",
        cfg: {rate: 100},
        chk: {sec: 5, etolerance: [6], with_pre_tx: true}
    },
    {
        txt: "Policer bit rate 1000 kbps",
        cfg: {rate: 1000},
        chk: {sec: 3, etolerance: [3]}
    },
    {
        txt: "Policer bit rate 10000 kbps",
        cfg: {rate: 10000},
        chk: {etolerance: [2]}
    },
    {
        txt: "Policer bit rate 100000 kbps",
        cfg: {level: 1, rate: 100000},
        chk: {etolerance: [2]}
    },
    {
        txt: "Policer bit rate 1000000 kbps",
        cfg: {level: 1, rate: 1000000},
        chk: {etolerance: [2]}
    },
    {
        txt: "Policer frame rate 100 fps",
        cfg: {frame_rate: true, rate: 100},
        chk: {sec: 3, etolerance: [2], with_pre_tx: true}
    },
    {
        txt: "Policer frame rate 1000 fps",
        cfg: {frame_rate: true, rate: 1000},
        chk: {sec: 2, with_pre_tx: true}
    },
    {
        txt: "Policer frame rate 10000 fps",
        cfg: {rame_rate: true, level: 206, rate: 10000},
        chk: {with_pre_tx: true}
    },
    {
        txt: "Policer frame rate 100000 fps",
        cfg: {rame_rate: true, level: 206, rate: 100000},
        chk: {etolerance: [2]}
    },
]



# Policer test function
def policer_test(t)
    cfg = fld_get(t, :cfg)
    chk = fld_get(t, :chk)
    cfg[:idx] = 0

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
    chk[:ig] = [0]
    chk[:eg] = 1
    chk[:size] = 1000
    rate_multiplier = cfg[:frame_rate] ? 1 : 1000
    chk[:erate] = [cfg[:rate] * rate_multiplier]
    chk[:frame_rate] = cfg[:frame_rate]
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