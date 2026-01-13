#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'
require_relative 'libeasy/utils'

$ts = get_test_setup("mesa_pc_b2b_2x")
$cap_family = $ts.dut.call("mesa_capability", "MESA_CAP_MISC_CHIP_FAMILY")

test_table =
[
    {
        txt: "Policer disabled",
        cfg: {idx: 0, rate: 0xffffffff},
        chk: {etolerance: [2], with_pre_tx: false}
    },
    {
        txt: "Policer line rate 100 kbps",
        cfg: {idx: 0, level: 1024, rate: 100},
        chk: {sec: 10, etolerance: [15]}    # High Tolerance to account for worst-case scenario with certain device families
    },
    {
        txt: "Policer line rate 5000 kbps (5 Mbps)",
        cfg: {idx: 1, level: 1024, rate: 5000},
    },
    {
        txt: "Policer line rate 30000 kbps (30 Mbps)",
        cfg: {idx: 0, level: 2048, rate: 30000},
    },
    {
        txt: "Policer line rate 60000 kbps (60 Mbps)",
        cfg: {idx: 1, level: 2048, rate: 60000},
        chk: {etolerance: [1.3]}
    },
    {
        txt: "Policer line rate 300000 kbps (300 Mbps)",
        cfg: {idx: 0, level: 4096, rate: 300000},
        chk: {etolerance: [2]}
    },
    {
        txt: "Policer line rate 600000 kbps (600 Mbps)",
        cfg: {idx: 1, level: 4096, rate: 600000},
        chk: {etolerance: [2.4]}
    },
    {
        txt: "Policer line rate 999000 kbps (999 Mbps)",
        cfg: {idx: 0, level: 4096, rate: 999000},
        chk: {etolerance: [2.7]}
    }
]

def policer_test(t)
    cfg = fld_get(t, :cfg)
    chk = fld_get(t, :chk, {})
    port = $ts.dut.p[fld_get(cfg, :idx)]
    eg = cfg[:idx] == 1 ? 0 : 1
    eg_port = $ts.dut.p[eg]

    ingress_ctag_aware(port)
    ingress_tag_pcp_mapping(port)
    egress_ctag_all(eg_port)

    [0,3,7].each do |queue|
        configure_queue_port(cfg, port, queue)
        setup_chk_params(cfg, chk, queue)
        check_rate(chk)
    end
end

def ingress_ctag_aware(port)
    conf = $ts.dut.call("mesa_vlan_port_conf_get", port)
    conf["port type"] = "MESA_VLAN_PORT_TYPE_C"
    $ts.dut.call("mesa_vlan_port_conf_set", port, conf)
end

def ingress_tag_pcp_mapping(port)
    conf = $ts.dut.call("mesa_qos_port_conf_get", port)
    conf["tag"]["class_enable"] = true
    conf["default_prio"] = 0
    conf["default_dpl"] = 0
    $ts.dut.call("mesa_qos_port_conf_set", port, conf)
end

def egress_ctag_all(port)
    conf = $ts.dut.call("mesa_vlan_port_conf_get", port)
    conf["port type"] = "MESA_VLAN_PORT_TYPE_C"
    conf["untagged_vid"] = 0
    $ts.dut.call("mesa_vlan_port_conf_set", port, conf)
end

def configure_queue_port(cfg, port, q)
    conf = $ts.dut.call("mesa_qos_port_conf_get", port)
    conf["queue"][q]["policer"]["level"] = fld_get(cfg, :level)
    conf["queue"][q]["policer"]["rate"] = cfg[:rate]
    $ts.dut.call("mesa_qos_port_conf_set", port, conf)
end

def setup_chk_params(cfg, chk, q)
    chk[:ig] = [cfg[:idx]]
    chk[:eg] = cfg[:idx] == 1 ? 0 : 1
    chk[:size] = 1000
    chk[:erate] = [cfg[:rate] * 1000]
    chk[:with_pre_tx] = fld_get(chk, :with_pre_tx, true)
    chk[:pcp] = [default_cos2pcp(q)]
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
