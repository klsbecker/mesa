#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'

$ts = get_test_setup("mesa_pc_b2b_2x")

cap_check_exit("L2_BUM_POL_CNT")

$iflow = nil

test_table = [
    {
        txt: "discard-unknown-uc",
        cfg: {bucket: [{u_uc: true}]},
        frm: [{uc: true, fwd: false}, {mc: true, fwd: true}, {bc: true, fwd: true}],
        cnt: {uc_discarded: 1, mc_passed: 1, bc_passed: 1},
    },
    {
        txt: "discard-known-uc",
        cfg: {bytes: true, bucket: [{k_uc: true}]},
        mac: [{uc: true}],
        frm: [{uc: true, fwd: false}, {mc: true, fwd: true}, {bc: true, fwd: true}],
        cnt: {uc_discarded: 64, mc_passed: 64, bc_passed: 64},
    },
    {
        txt: "discard-unknown-mc",
        cfg: {bucket: [{u_mc: true}]},
        frm: [{uc: true, fwd: true}, {mc: true, fwd: false}, {bc: true, fwd: true}],
        cnt: {uc_passed: 1, mc_discarded: 1, bc_passed: 1},
    },
    {
        txt: "discard-known-mc",
        cfg: {bytes: true, bucket: [{k_mc: true}]},
        mac: [{mc: true}],
        frm: [{uc: true, fwd: true}, {mc: true, fwd: false}, {bc: true, fwd: true}],
        cnt: {uc_passed: 64, mc_discarded: 64, bc_passed: 64},
    },
    {
        txt: "discard-unknown-bc",
        cfg: {bucket: [{u_bc: true}]},
        frm: [{uc: true, fwd: true}, {mc: true, fwd: true}, {bc: true, fwd: false}],
        cnt: {uc_passed: 1, mc_passed: 1, bc_discarded: 1},
    },
    {
        txt: "discard-known-bc",
        cfg: {bytes: true, bucket: [{k_bc: true}]},
        mac: [{bc: true}],
        frm: [{uc: true, fwd: true}, {mc: true, fwd: true}, {bc: true, fwd: false}],
        cnt: {uc_passed: 64, mc_passed: 64, bc_discarded: 64},
    },
    {
        txt: "line-1-Mbps",
        cfg: {bucket: [{u_uc: true}]},
        pol: {b: [{r: 1000}]},
        chk: [{uc: true, r: 1000}],
    },
    {
        txt: "line-10-Mbps",
        cfg: {bucket: [{u_mc: true}]},
        pol: {b: [{r: 10_000}]},
        chk: [{mc: true, r: 10_000}],
    },
    {
        txt: "line-100-Mbps",
        cfg: {bucket: [{u_bc: true}]},
        pol: {b: [{r: 100_000}]},
        chk: [{bc: true, r: 100_000}],
    },
    {
        txt: "data-1-Mbps",
        cfg: {bucket: [{u_uc: true}]},
        pol: {mode: "data", b: [{r: 1000}]},
        chk: [{uc: true, r: 1000}],
    },
    {
        txt: "data-10-Mbps",
        cfg: {bucket: [{u_mc: true}]},
        pol: {mode: "data", b: [{r: 10_000}]},
        chk: [{mc: true, r: 10_000}],
    },
    {
        txt: "data-100-Mbps",
        cfg: {bucket: [{u_bc: true}]},
        pol: {mode: "data", b: [{r: 100_000}]},
        chk: [{bc: true, r: 100_000}],
    },
    {
        txt: "frame-100-fps",
        cfg: {bucket: [{u_uc: true}]},
        pol: {mode: "frame", b: [{r: 100}]},
        chk: [{uc: true, r: 100}],
    },
    {
        txt: "frame-1000-fps",
        cfg: {bucket: [{u_mc: true}]},
        pol: {mode: "frame", b: [{r: 1000}]},
        chk: [{mc: true, r: 1000}],
    },
    {
        txt: "frame-10-kfps",
        cfg: {bucket: [{u_bc: true}]},
        pol: {mode: "frame", b: [{r: 10_000}]},
        chk: [{bc: true, r: 10_000}],
    },
    {
        txt: "frame-100-kfps",
        cfg: {bucket: [{u_uc: true}]},
        pol: {mode: "frame", b: [{r: 100_000}]},
        chk: [{uc: true, r: 100_000}],
    },
    {
        txt: "line-uuc-kmc-ubc",
        cfg: {bucket: [{u_uc: true}, {k_mc: true}, {u_bc: true}]},
        pol: {b: [{r: 10_000}, {r: 20_000}, {r: 30_000}]},
        mac: [{mc: true}],
        chk: [{uc: true, r: 10_000}, {mc: true, r: 20_000}, {bc: true, r: 30_000}],
    },
    {
        txt: "line-kuc-umc-kbc",
        cfg: {bucket: [{k_uc: true}, {u_mc: true}, {k_bc: true}]},
        pol: {b: [{r: 10_000}, {r: 20_000}, {r: 30_000}]},
        mac: [{uc: true}, {bc: true}],
        chk: [{uc: true, r: 10_000}, {mc: true, r: 20_000}, {bc: true, r: 30_000}],
    },
]

def bum_mac_get(e)
    str = ""
    if (e[:uc])
        str = "00:01:02:03:04:05"
    elsif (e[:mc])
        str = "01:02:03:04:05:06"
    else
        str = "ff:ff:ff:ff:ff:ff"
    end
    return str
end

def bum_test(t)
    idx_tx = 0
    idx_rx = 1

    # Iflow allocation and VCE
    if ($iflow == nil)
        $iflow = $ts.dut.call("mesa_iflow_alloc")
        c = $ts.dut.call("mesa_vce_init", "MESA_VCE_TYPE_ANY")
        c["id"] = 1
        c["key"]["port_list"] = "#{$ts.dut.p[idx_tx]}"
        c["action"]["flow_id"] = $iflow
        $ts.dut.call("mesa_vce_add", 0, c)
    end

    # General BUM configuration
    cfg = t[:cfg]
    c = $ts.dut.call("mesa_bum_conf_get")
    c["cnt_bytes"] = fld_get(cfg, :bytes, false)
    c["bucket"].each_with_index do |b, i|
        e = cfg[:bucket][i]
        b["known_unicast"] = fld_get(e, :k_uc, false)
        b["known_multicast"] = fld_get(e, :k_mc, false)
        b["known_broadcast"] = fld_get(e, :k_bc, false)
        b["unknown_unicast"] = fld_get(e, :u_uc, false)
        b["unknown_multicast"] = fld_get(e, :u_mc, false)
        b["unknown_broadcast"] = fld_get(e, :u_bc, false)
    end
    $ts.dut.call("mesa_bum_conf_set", c)

    # BUM policer configuration
    pol = t[:pol]
    id = fld_get(pol, :id)
    c = $ts.dut.call("mesa_bum_policer_conf_get", id)
    mode = fld_get(pol, :mode, "line")
    frame_rate = (mode == "frame")
    c["mode"] = ("MESA_POLICER_MODE_" + mode.upcase)
    tab = fld_get(pol, :b, [])
    c["bucket"].each_with_index do |b, i|
        e = tab[i]
        rate = fld_get(e, :r)
        b["rate"] = rate
        b["level"] = fld_get(e, :l, rate == 0 ? 0 : frame_rate ? 2: 2048)
    end
    $ts.dut.call("mesa_bum_policer_conf_set", id, c)

    # Iflow mapping
    c = $ts.dut.call("mesa_iflow_conf_get", $iflow)
    c["bum_enable"] = true
    c["bum_id"] = id
    $ts.dut.call("mesa_iflow_conf_set", $iflow, c)

    # Add MAC addresses
    mac_table = []
    mac = fld_get(t, :mac, [])
    mac.each do |m|
        a = bum_mac_get(m).split(":").map {|e| e.to_i(16)} 
        vm = {vid: 1, mac: {addr: a}}
        mac_table.push(vm)
        e = {
            vid_mac: vm,
            destination: "#{$ts.dut.p[idx_rx]}",
            copy_to_cpu: false,
            copy_to_cpu_smac: false,
            locked: true,
            index_table: false,
            aged: false,
            cpu_queue: 0,
        }
        $ts.dut.call("mesa_mac_table_add", e)
    end

    # Frame rate test
    chk = fld_get(t, :chk, [])
    chk.each do |e|
        c = {}
        c[:ig] = [idx_tx]
        c[:eg] = idx_rx
        c[:size] = 1000
        c[:frame_rate] = frame_rate
        c[:data_rate] = (mode == "data")
        c[:erate] = [(frame_rate ? 1 : 1000) * e[:r]]
        c[:etolerance] = [3]
        c[:dmac] = bum_mac_get(e)
        check_rate(c)
    end

    # Frame discard test
    idx_list = []
    $ts.dut.p.each_index do |idx|
        idx_list.push(idx) if idx != idx_tx
    end
    frm = fld_get(t, :frm, [])
    frm.each do |e|
        dmac = bum_mac_get(e)
        run_ef_tx_rx_cmd($ts, idx_tx, e[:fwd] ? idx_list : [], "eth dmac #{dmac}")
    end

    # Counters
    c = $ts.dut.call("mesa_bum_policer_cnt_get", id)
    cnt = fld_get(t, :cnt, nil)
    if (cnt != nil)
        ["uc_passed", "mc_passed", "bc_passed", "uc_discarded", "mc_discarded", "bc_discarded" ].each do |name|
            val = cnt[name.to_sym]
            check_counter(name, c[name], val ? val : 0)
        end
    end
    $ts.dut.call("mesa_bum_policer_cnt_clear", id)

    # Delete MAC addresses
    mac_table.each do |e|
        $ts.dut.call("mesa_mac_table_del", e)
    end
end

sel = table_lookup(test_table, :sel)
test_table.each do |t|
    next if (t[:sel] != sel)
    test t[:txt] do
        bum_test(t)
    end
end

test_summary

test "dump" do
    #$ts.dut.run("mesa-cmd deb api ai vx action 7")
end
