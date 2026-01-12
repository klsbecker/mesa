#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'

$ts = get_test_setup("mesa_pc_b2b_4x")

# VLANs used in this test
vid_a = 100
vid_b = 200
vid_c = 300
vid_z = 400

s_etype = 0x9100

test_table =
[
    {
        txt: "pvid",
        cfg: [{idx: 0, pvid: vid_a},
              {idx: 1},
              {idx: 2}],
        vln: [{vid: vid_a, idx_list: [0,1,2]}],
        frm: [[{idx_tx: 0}, {idx_rx: 1, ot: ["c", vid_a]}, {idx_rx: 2, ot: ["c", vid_a]}]],
    },
    {
        txt: "port-type",
        ets: s_etype,
        cfg: [{idx: 0, pvid: vid_a},
              {idx: 1, port_type: "C", pvid: vid_z},
              {idx: 2, port_type: "S", pvid: vid_z},
              {idx: 3, port_type: "S_CUSTOM", pvid: vid_z}],
        vln: [{vid: vid_a, idx_list: [0,1]},
              {vid: vid_b, idx_list: [0,2]},
              {vid: vid_c, idx_list: [0,3]}],
        frm: [
            # Ingress port is unaware
            [{idx_tx: 0}, {idx_rx: 1, ot: ["c", vid_a]}],
            # Ingress port is C-aware
            [{idx_tx: 1}],
            [{idx_tx: 1, ot: ["c", 0]}],
            [{idx_tx: 1, ot: ["c", vid_a]}, {idx_rx: 0, ot: ["c", vid_a]}],
            [{idx_tx: 1, ot: ["s", 0]}],
            [{idx_tx: 1, ot: ["s", vid_a]}, {cap: 0, idx_rx: 0, ot: ["c", vid_a]}],
            [{idx_tx: 1, ot: ["x", 0]}],
            [{idx_tx: 1, ot: ["x", vid_a]}, {cap: 0, idx_rx: 0, ot: ["c", vid_a]}],
            # Ingress port is S-aware
            [{idx_tx: 2}],
            [{idx_tx: 2, ot: ["c", 0]}],
            [{idx_tx: 2, ot: ["c", vid_b]}, {cap: 0, idx_rx: 0, ot: ["c", vid_b]}],
            [{idx_tx: 2, ot: ["s", 0]}],
            [{idx_tx: 2, ot: ["s", vid_b]}, {idx_rx: 0, ot: ["c", vid_b]}],
            [{idx_tx: 2, ot: ["x", 0]}],
            [{idx_tx: 2, ot: ["x", vid_b]}, {cap: 0, idx_rx: 0, ot: ["c", vid_b]}],
            # Ingress port is S-custom-aware
            [{idx_tx: 3}],
            [{idx_tx: 3, ot: ["c", 0]}],
            [{idx_tx: 3, ot: ["c", vid_c]}, {cap: 0, idx_rx: 0, ot: ["c", vid_c]}],
            [{idx_tx: 3, ot: ["s", 0]}],
            [{idx_tx: 3, ot: ["s", vid_c]}, {cap: 0, idx_rx: 0, ot: ["c", vid_c]}],
            [{idx_tx: 3, ot: ["x", 0]}],
            [{idx_tx: 3, ot: ["x", vid_c]}, {idx_rx: 0, ot: ["c", vid_c]}],
        ],
    },
    {
        txt: "uvid",
        cfg: [{idx: 0, port_type: "C"},
              # Tag all VLANs
              {idx: 1, uvid: 0},
              # Tag VLAN A
              {idx: 2, uvid: vid_a},
              # Untag all VLANs
              {idx: 3, uvid: 4096}],
        vln: [{vid: vid_a, idx_list: [0,1,2,3]},
              {vid: vid_b, idx_list: [0,1,2,3]}],
        frm: [
            [{idx_tx: 0, ot: ["c", vid_a]},
             {idx_rx: 1, ot: ["c", vid_a]},
             {idx_rx: 2},
             {idx_rx: 3}],
            [{idx_tx: 0, ot: ["c", vid_b]},
             {idx_rx: 1, ot: ["c", vid_b]},
             {idx_rx: 2, ot: ["c", vid_b]},
             {idx_rx: 3}],
        ],
    },
    {
        txt: "ingress-filter",
        cfg: [{idx: 0, pvid: vid_a},
              {idx: 1, pvid: vid_a, ingress_filter: true},
              {idx: 2, uvid: vid_a}],
        vln: [{vid: vid_a, idx_list: [2]}],
        frm: [
            # Ingress port with filtering disabled
            [{idx_tx: 0}, {idx_rx: 2}],
            # Ingress port with filtering enabled
            [{idx_tx: 1}],
        ],
    },
    {
        txt: "frame-type-all",
        ets: s_etype,
        cfg: [{idx: 0, pvid: vid_b, uvid: vid_a},
              {idx: 1, port_type: "C", pvid: vid_a, uvid: vid_b},
              {idx: 2, port_type: "S", pvid: vid_a},
              {idx: 3, port_type: "S_CUSTOM", pvid: vid_a}],
        vln: [{vid: vid_a, idx_list: [0]},
              {vid: vid_b, idx_list: [1]}],
        frm: [
            # Ingress port is unaware
            [{idx_tx: 0}, {idx_rx: 1}],
            [{idx_tx: 0, ot: ["c", 0]}, {idx_rx: 1, ot: ["c", 0]}],
            [{idx_tx: 0, ot: ["c", 1]}, {idx_rx: 1, ot: ["c", 1]}],
            [{idx_tx: 0, ot: ["s", 0]}, {idx_rx: 1, ot: ["s", 0]}],
            [{idx_tx: 0, ot: ["s", 1]}, {idx_rx: 1, ot: ["s", 1]}],
            [{idx_tx: 0, ot: ["x", 0]}, {idx_rx: 1, ot: ["x", 0]}],
            [{idx_tx: 0, ot: ["x", 1]}, {idx_rx: 1, ot: ["x", 1]}],
            # Ingress port is C-aware
            [{idx_tx: 1}, {idx_rx: 0}],
            [{idx_tx: 1, ot: ["c", 0]}, {idx_rx: 0}],
            [{idx_tx: 1, ot: ["c", vid_a]}, {idx_rx: 0}],
            [{idx_tx: 1, ot: ["s", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["s", 0]}],
            [{idx_tx: 1, ot: ["s", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["s", vid_a]}],
            [{idx_tx: 1, ot: ["x", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["x", 0]}],
            [{idx_tx: 1, ot: ["x", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["x", vid_a]}],
            # Ingress port is S-aware
            [{idx_tx: 2}, {idx_rx: 0}],
            [{idx_tx: 2, ot: ["c", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["c", 0]}],
            [{idx_tx: 2, ot: ["c", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["c", vid_a]}],
            [{idx_tx: 2, ot: ["s", 0]}, {idx_rx: 0}],
            [{idx_tx: 2, ot: ["s", vid_a]}, {idx_rx: 0}],
            [{idx_tx: 2, ot: ["x", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["x", 0]}],
            [{idx_tx: 2, ot: ["x", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["x", vid_a]}],
            # Ingress port is S-custom-aware
            [{idx_tx: 3}, {idx_rx: 0}],
            [{idx_tx: 3, ot: ["c", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["c", 0]}],
            [{idx_tx: 3, ot: ["c", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["c", vid_a]}],
            [{idx_tx: 3, ot: ["s", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["s", 0]}],
            [{idx_tx: 3, ot: ["s", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["s", vid_a]}],
            [{idx_tx: 3, ot: ["x", 0]}, {idx_rx: 0}],
            [{idx_tx: 3, ot: ["x", vid_a]}, {idx_rx: 0}],
        ],
    },
    {
        txt: "frame-type-tagged",
        ets: s_etype,
        cfg: [{idx: 0, pvid: vid_b, uvid: vid_a, frame_type: "TAGGED"},
              {idx: 1, port_type: "C", pvid: vid_a, uvid: vid_b, frame_type: "TAGGED"},
              {idx: 2, port_type: "S", pvid: vid_a, frame_type: "TAGGED"},
              {idx: 3, port_type: "S_CUSTOM", pvid: vid_a, frame_type: "TAGGED"}],
        vln: [{vid: vid_a, idx_list: [0]},
              {vid: vid_b, idx_list: [1]}],
        frm: [
            # Ingress port is unaware, allow all
            [{idx_tx: 0}, {idx_rx: 1}],
            [{idx_tx: 0, ot: ["c", 0]}, {idx_rx: 1, ot: ["c", 0]}],
            [{idx_tx: 0, ot: ["c", 1]}, {idx_rx: 1, ot: ["c", 1]}],
            [{idx_tx: 0, ot: ["s", 0]}, {idx_rx: 1, ot: ["s", 0]}],
            [{idx_tx: 0, ot: ["s", 1]}, {idx_rx: 1, ot: ["s", 1]}],
            [{idx_tx: 0, ot: ["x", 0]}, {idx_rx: 1, ot: ["x", 0]}],
            [{idx_tx: 0, ot: ["x", 1]}, {idx_rx: 1, ot: ["x", 1]}],
            # Ingress port is C-aware, allow only C-vlan-tagged
            [{idx_tx: 1}],
            [{idx_tx: 1, ot: ["c", 0]}],
            [{idx_tx: 1, ot: ["c", vid_a]}, {idx_rx: 0}],
            [{idx_tx: 1, ot: ["s", 0]}],
            [{idx_tx: 1, ot: ["s", vid_a]}],
            [{idx_tx: 1, ot: ["x", 0]}],
            [{idx_tx: 1, ot: ["x", vid_a]}],
            # Ingress port is S-aware, allow only S-vlan-tagged
            [{idx_tx: 2}],
            [{idx_tx: 2, ot: ["c", 0]}],
            [{idx_tx: 2, ot: ["c", vid_a]}],
            [{idx_tx: 2, ot: ["s", 0]}],
            [{idx_tx: 2, ot: ["s", vid_a]}, {idx_rx: 0}],
            [{idx_tx: 2, ot: ["x", 0]}],
            [{idx_tx: 2, ot: ["x", vid_a]}, {cap: 0, idx_rx: 0}],
            # Ingress port is S-custom-aware, allow only S-custom-VLAN-tagged
            [{idx_tx: 3}],
            [{idx_tx: 3, ot: ["c", 0]}],
            [{idx_tx: 3, ot: ["c", vid_a]}],
            [{idx_tx: 3, ot: ["s", 0]}],
            [{idx_tx: 3, ot: ["s", vid_a]}, {cap: 0, idx_rx: 0}],
            [{idx_tx: 3, ot: ["x", 0]}],
            [{idx_tx: 3, ot: ["x", vid_a]}, {idx_rx: 0}],
        ],
    },
    {
        txt: "frame-type-untagged",
        ets: s_etype,
        cfg: [{idx: 0, pvid: vid_b, uvid: vid_a, frame_type: "UNTAGGED"},
              {idx: 1, port_type: "C", pvid: vid_a, uvid: vid_b, frame_type: "UNTAGGED"},
              {idx: 2, port_type: "S", pvid: vid_a, frame_type: "UNTAGGED"},
              {idx: 3, port_type: "S_CUSTOM", pvid: vid_a, frame_type: "UNTAGGED"}],
        vln: [{vid: vid_a, idx_list: [0]},
              {vid: vid_b, idx_list: [1]}],
        frm: [
            # Ingress port is unaware, allow all
            [{idx_tx: 0}, {idx_rx: 1}],
            [{idx_tx: 0, ot: ["c", 0]}, {idx_rx: 1, ot: ["c", 0]}],
            [{idx_tx: 0, ot: ["c", 1]}, {idx_rx: 1, ot: ["c", 1]}],
            [{idx_tx: 0, ot: ["s", 0]}, {idx_rx: 1, ot: ["s", 0]}],
            [{idx_tx: 0, ot: ["s", 1]}, {idx_rx: 1, ot: ["s", 1]}],
            [{idx_tx: 0, ot: ["x", 0]}, {idx_rx: 1, ot: ["x", 0]}],
            [{idx_tx: 0, ot: ["x", 1]}, {idx_rx: 1, ot: ["x", 1]}],
            # Ingress port is C-aware, discard C-vlan-tagged
            [{idx_tx: 1}, {idx_rx: 0}],
            [{idx_tx: 1, ot: ["c", 0]}, {idx_rx: 0}],
            [{idx_tx: 1, ot: ["c", vid_a]}],
            [{idx_tx: 1, ot: ["s", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["s", 0]}],
            [{idx_tx: 1, ot: ["s", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["s", vid_a]}],
            [{idx_tx: 1, ot: ["x", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["x", 0]}],
            [{idx_tx: 1, ot: ["x", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["x", vid_a]}],
            # Ingress port is S-aware, discard S-vlan-tagged
            [{idx_tx: 2}, {idx_rx: 0}],
            [{idx_tx: 2, ot: ["c", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["c", 0]}],
            [{idx_tx: 2, ot: ["c", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["c", vid_a]}],
            [{idx_tx: 2, ot: ["s", 0]}, {idx_rx: 0}],
            [{idx_tx: 2, ot: ["s", vid_a]}],
            [{idx_tx: 2, ot: ["x", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["x", 0]}],
            [{idx_tx: 2, ot: ["x", vid_a]}, {cap: 1, idx_rx: 0, ot: ["x", vid_a]}],
            # Ingress port is S-custom-aware, discard S-custom-vlan-tagged
            [{idx_tx: 3}, {idx_rx: 0}],
            [{idx_tx: 3, ot: ["c", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["c", 0]}],
            [{idx_tx: 3, ot: ["c", vid_a]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["c", vid_a]}],
            [{idx_tx: 3, ot: ["s", 0]}, {cap: 0, idx_rx: 0}, {cap: 1, idx_rx: 0, ot: ["s", 0]}],
            [{idx_tx: 3, ot: ["s", vid_a]}, {cap: 1, idx_rx: 0, ot: ["s", vid_a]}],
            [{idx_tx: 3, ot: ["x", 0]}, {idx_rx: 0}],
            [{idx_tx: 3, ot: ["x", vid_a]}],
        ],
    },
    {
        txt: "outer-tag-discard-c",
        ets: s_etype,
        cfg: [{idx: 0, pvid: vid_a, uvid: 4096, ot: {no_tag: true}},
              {idx: 1, pvid: vid_a, uvid: vid_a, ot: {c_prio_tag: true}},
              {idx: 2, pvid: vid_b, ot: {c_tag: true}}],
        vln: [{vid: vid_a, idx_list: [0,1]},
              {vid: vid_b, idx_list: [0,2]}],
        frm: [
            # Index 0, discard untagged
            [{idx_tx: 0}],
            [{idx_tx: 0, ot: ["c", 0]}, {idx_rx: 1, ot: ["c", 0]}],
            [{idx_tx: 0, ot: ["c", 1]}, {idx_rx: 1, ot: ["c", 1]}],
            [{idx_tx: 0, ot: ["s", 0]}, {idx_rx: 1, ot: ["s", 0]}],
            [{idx_tx: 0, ot: ["s", 1]}, {idx_rx: 1, ot: ["s", 1]}],
            [{idx_tx: 0, ot: ["x", 0]}, {idx_rx: 1, ot: ["x", 0]}],
            [{idx_tx: 0, ot: ["x", 1]}, {idx_rx: 1, ot: ["x", 1]}],
            # Index 1, discard C-prio-tagged
            [{idx_tx: 1}, {idx_rx: 0}],
            [{idx_tx: 1, ot: ["c", 0]}],
            [{idx_tx: 1, ot: ["c", 1]}, {idx_rx: 0, ot: ["c", 1]}],
            [{idx_tx: 1, ot: ["s", 0]}, {idx_rx: 0, ot: ["s", 0]}],
            [{idx_tx: 1, ot: ["s", 1]}, {idx_rx: 0, ot: ["s", 1]}],
            [{idx_tx: 1, ot: ["x", 0]}, {idx_rx: 0, ot: ["x", 0]}],
            [{idx_tx: 1, ot: ["x", 1]}, {idx_rx: 0, ot: ["x", 1]}],
            # Index 2, discard C-vlan-tagged
            [{idx_tx: 2}, {idx_rx: 0}],
            [{idx_tx: 2, ot: ["c", 0]}, {idx_rx: 0, ot: ["c", 0]}],
            [{idx_tx: 2, ot: ["c", 1]}],
            [{idx_tx: 2, ot: ["s", 0]}, {idx_rx: 0, ot: ["s", 0]}],
            [{idx_tx: 2, ot: ["s", 1]}, {idx_rx: 0, ot: ["s", 1]}],
            [{idx_tx: 2, ot: ["x", 0]}, {idx_rx: 0, ot: ["x", 0]}],
            [{idx_tx: 2, ot: ["x", 1]}, {idx_rx: 0, ot: ["x", 1]}],
        ],
    },
    {
        txt: "outer-tag-discard-s",
        ets: s_etype,
        cfg: [{idx: 0, pvid: vid_a, uvid: 4096, ot: {s_prio_tag: true}},
              {idx: 1, pvid: vid_a, uvid: vid_a, ot: {s_tag: true}},
              {idx: 2, pvid: vid_b, ot: {s_custom_prio_tag: true}},
              {idx: 3, pvid: vid_c, ot: {s_custom_tag: true}}],
        vln: [{vid: vid_a, idx_list: [0,1]},
              {vid: vid_b, idx_list: [0,2]},
              {vid: vid_c, idx_list: [0,3]}],
        frm: [
            # Index 0, discard S-prio-tagged
            [{idx_tx: 0}, {idx_rx: 1}],
            [{idx_tx: 0, ot: ["c", 0]}, {idx_rx: 1, ot: ["c", 0]}],
            [{idx_tx: 0, ot: ["c", 1]}, {idx_rx: 1, ot: ["c", 1]}],
            [{idx_tx: 0, ot: ["s", 0]}],
            [{idx_tx: 0, ot: ["s", 1]}, {idx_rx: 1, ot: ["s", 1]}],
            [{idx_tx: 0, ot: ["x", 0]}, {cap: 1, idx_rx: 1, ot: ["x", 0]}],
            [{idx_tx: 0, ot: ["x", 1]}, {idx_rx: 1, ot: ["x", 1]}],
            # Index 1, discard S-vlan-tagged
            [{idx_tx: 1}, {idx_rx: 0}],
            [{idx_tx: 1, ot: ["c", 0]}, {idx_rx: 0, ot: ["c", 0]}],
            [{idx_tx: 1, ot: ["c", 1]}, {idx_rx: 0, ot: ["c", 1]}],
            [{idx_tx: 1, ot: ["s", 0]}, {idx_rx: 0, ot: ["s", 0]}],
            [{idx_tx: 1, ot: ["s", 1]}],
            [{idx_tx: 1, ot: ["x", 0]}, {idx_rx: 0, ot: ["x", 0]}],
            [{idx_tx: 1, ot: ["x", 1]}, {cap: 1, idx_rx: 0, ot: ["x", 1]}],
            # Index 2, discard S-custom-prio-tagged
            [{idx_tx: 2}, {idx_rx: 0}],
            [{idx_tx: 2, ot: ["c", 0]}, {idx_rx: 0, ot: ["c", 0]}],
            [{idx_tx: 2, ot: ["c", 1]}, {idx_rx: 0, ot: ["c", 1]}],
            [{idx_tx: 2, ot: ["s", 0]}, {idx_rx: 0, ot: ["s", 0]}],
            [{idx_tx: 2, ot: ["s", 1]}, {idx_rx: 0, ot: ["s", 1]}],
            [{idx_tx: 2, ot: ["x", 0]}, {cap: 0, idx_rx: 0, ot: ["x", 0]}],
            [{idx_tx: 2, ot: ["x", 1]}, {idx_rx: 0, ot: ["x", 1]}],
            # Index 3, discard S-custom-vlan-tagged 
            [{idx_tx: 3}, {idx_rx: 0}],
            [{idx_tx: 3, ot: ["c", 0]}, {idx_rx: 0, ot: ["c", 0]}],
            [{idx_tx: 3, ot: ["c", 1]}, {idx_rx: 0, ot: ["c", 1]}],
            [{idx_tx: 3, ot: ["s", 0]}, {idx_rx: 0, ot: ["s", 0]}],
            [{idx_tx: 3, ot: ["s", 1]}, {idx_rx: 0, ot: ["s", 1]}],
            [{idx_tx: 3, ot: ["x", 0]}, {idx_rx: 0, ot: ["x", 0]}],
            [{idx_tx: 3, ot: ["x", 1]}, {cap: 0, idx_rx: 0, ot: ["x", 1]}],
        ],
    },
]

def tag_discard_set(d, e)
    d["no_tag"] = fld_get(e, :no_tag, false)
    d["c_tag"] = fld_get(e, :c_tag, false)
    d["c_prio_tag"] = fld_get(e, :c_prio_tag, false)
    d["s_tag"] = fld_get(e, :s_tag, false)
    d["s_prio_tag"] = fld_get(e, :s_prio_tag, false)
    d["s_custom_tag"] = fld_get(e, :s_custom_tag, false)
    d["s_custom_prio_tag"] = fld_get(e, :s_custom_prio_tag, false)
end

$cap_aware = nil
def cap_aware_get
    if ($cap_aware == nil)
        $cap_aware = cap_get("L2_TPID_AWARE")
    end
    return $cap_aware
end

def vlan_test(t)
    # Global Ethernet Type
    ets = t[:ets]
    if (ets != nil)
        c = $ts.dut.call("mesa_vlan_conf_get")
        c["s_etype"] = ets
        $ts.dut.call("mesa_vlan_conf_set", c)
    end

    # Port configuration
    cfg = fld_get(t, :cfg, [])
    cfg.each do |e|
        port = $ts.dut.p[e[:idx]]
        c = $ts.dut.call("mesa_vlan_port_conf_get", port)
        c["port_type"] = ("MESA_VLAN_PORT_TYPE_" + fld_get(e, :port_type, "UNAWARE"))
        c["pvid"] = fld_get(e, :pvid, 1)
        c["untagged_vid"] = fld_get(e, :uvid, 1)
        c["frame_type"] = ("MESA_VLAN_FRAME_" + fld_get(e, :frame_type, "ALL")) 
        c["ingress_filter"] = fld_get(e, :ingress_filter, false)
        tag_discard_set(c["outer_tag_discard"], fld_get(e, :ot, {}))
        tag_discard_set(c["inner_tag_discard"], fld_get(e, :it, {}))
        $ts.dut.call("mesa_vlan_port_conf_set", port, c)
    end

    # VLAN configuration
    vln = fld_get(t, :vln, [])
    vln.each do |e|
        $ts.dut.call("mesa_vlan_port_members_set", e[:vid], port_idx_list_str(e[:idx_list]))
    end

    # Frame test
    frm = fld_get(t, :frm, [])
    frm.each do |f|
        cmd = "ef"
        idx_list = []
        idx_tx = nil
        f.each do |e|
            cap = e[:cap]
            if (cap != nil && cap != cap_aware_get)
                # Skip due to awareness
                next
            end
            idx = e[:idx_tx]
            if (idx != nil)
                idx_tx = idx
            else
                idx = e[:idx_rx]
            end
            idx_list.push(idx)
            cmd += " name f#{idx} eth"
            2.times do |i|
                t = (i == 0 ? e[:ot] : e[:it])
                if (t != nil)
                    tpid = (t[0] == "c" ? 0x8100 : t[0] == "s" ? 0x88a8 : ets)
                    vid = t[1]
                    cmd += cmd_tag_push({tpid: tpid, vid: vid})
                end
            end
            cmd += " data pattern cnt 50"
        end
        $ts.pc.p.each_index do |idx|
            cmd += (idx == idx_tx ? " tx" : " rx")
            cmd += " #{$ts.pc.p[idx]}"
            if (idx_list.include?idx)
                cmd += " name f#{idx}"
            end
        end
        $ts.pc.run(cmd)
    end
end

# Run all or selected test
sel = table_lookup(test_table, :sel)
test_table.each do |t|
    test t[:txt] do
        next if (t[:sel] != sel)
        vlan_test(t)
    end
end

test_summary

test "dump" do
    #$ts.dut.run("mesa-cmd deb api ci vlan")
end
