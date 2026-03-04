#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'

$ts = get_test_setup("mesa_pc_b2b_4x")

test_table =
[
    {
        txt: "npi-tx-port",
        cfg: {idx_npi: 0},
        frm: {fwd: [{idx_tx: 0, ifh_tx: {idx: 1}}, {idx_rx: 1}]},
    },
    {
        txt: "npi-tx-vlan",
        cfg: {idx_npi: 0},
        frm: {drop: false, fwd: [{idx_tx: 0, ifh_tx: {vid: 1}}]},
    },
    {
        txt: "npi-rx-bpdu",
        cfg: {idx_npi: 1, bpdu_queue: 7, npi_queue: 7},
        frm: {dmac: "01:80:c2:00:00:00", fwd: [{idx_tx: 0}, {idx_rx:1, ifh_rx: {idx: 0}}]},
    },
    {
        txt: "port-rx-bpdu",
        cfg: {idx_port: 0, prio: 5, bpdu_queue: 7},
        frm: {dmac: "01:80:c2:00:00:00", fwd: [{idx_tx: 1}, {idx_rx:0}]},
    },
]

def npi_test(t)
    cfg = fld_get(t, :cfg, {})

    # NPI configuration
    idx_npi = cfg[:idx_npi]
    if (idx_npi != nil)
        c = $ts.dut.call("mesa_npi_conf_get")
        c["enable"] = true
        c["port_no"] = $ts.dut.p[idx_npi]
        $ts.dut.call("mesa_npi_conf_set", c)
    end

    # BPDU queue redirect
    bpdu_queue = cfg[:bpdu_queue]
    if (bpdu_queue != nil)
        c = $ts.dut.call("mesa_packet_rx_conf_get")
        c["reg"]["bpdu_cpu_only"] = true
        c["map"]["bpdu_queue"] = bpdu_queue
        q = c["queue"][bpdu_queue]["npi"]
        idx_port = cfg[:idx_port]
        if (idx_port == nil)
            q["enable"] = true
        else
            q["enable"] = false
            q["port_enable"] = true
            q["port_no"] = $ts.dut.p[idx_port]
            q["prio_enable"] = true
            q["prio"] = cfg[:prio]
        end
        $ts.dut.call("mesa_packet_rx_conf_set", c)
    end

    # Frame test
    frm = fld_get(t, :frm, {})
    cmd = "ef"
    cmd_add = ""
    idx_list = []
    dmac = fld_get(frm, :dmac, "ff:ff:ff:ff:ff:ff")
    f_base = "eth dmac #{dmac}"
    f_end = "data pattern cnt 46"
    frm[:fwd].each do |e|
        idx = e[:idx_tx]
        dir = "tx"
        if (idx == nil)
            dir = "rx"
            idx = e[:idx_rx]
        end
        idx_list.push(idx)
        cmd += (" name f#{idx}")
        ifh_rx = e[:ifh_rx]
        if (ifh_rx != nil)
            cmd += (" " + cmd_rx_ifh_push({port_idx: ifh_rx[:idx]}))
        end
        tag = ""
        ifh_tx = e[:ifh_tx]
        if (ifh_tx != nil)
            vid = ifh_tx[:vid]
            if (vid != nil)
                ifh = {switch_frm: true}
                tag = cmd_tag_push({tpid: 0x8100, vid: vid})
            else
                ifh = {dst_port: $ts.dut.p[ifh_tx[:idx]]}
            end
            cmd += (" " + cmd_tx_ifh_push(ifh))
        end
        cmd += " #{f_base} #{tag} #{f_end}"
        cmd_add += " #{dir} #{$ts.pc.p[idx]} name f#{idx}"
    end
    drop = fld_get(frm, :drop, true)
    $ts.pc.p.each_with_index do |name, idx|
        if (!idx_list.include?(idx))
            cmd_add += " rx #{name}"
            if (!drop)
                cmd += (" name f#{idx} #{f_base} #{f_end}")
                cmd_add += " name f#{idx}"
            end
        end
    end
    $ts.pc.try(cmd + cmd_add)

    # Return here when debugging a test
    #return

    # Remove NPI configuration
    if (idx_npi != nil)
        c = $ts.dut.call("mesa_npi_conf_get")
        c["enable"] = false
        $ts.dut.call("mesa_npi_conf_set", c)
    end

    # Remove BPDU queue configuration
    if (bpdu_queue != nil)
        c = $ts.dut.call("mesa_packet_rx_conf_get")
        c["reg"]["bpdu_cpu_only"] = true
        c["map"]["bpdu_queue"] = 0
        q = c["queue"][bpdu_queue]["npi"]
        q["enable"] = false
        q["port_enable"] = false
        q["prio_enable"] = false
        $ts.dut.call("mesa_packet_rx_conf_set", c)
    end
end

sel = table_lookup(test_table, :sel)
test_table.each do |t|
    next if (t[:sel] != sel)
    test t[:txt] do
        npi_test(t)
    end
end

test_summary

test "dump" do
    break
    $ts.dut.run("mesa-cmd deb api ci cou act 1")
    $ts.dut.run("mesa-cmd deb api packet")
    $ts.dut.run("mesa-cmd deb api ci cou #{$ts.dut.p[0] + 1} full")
end
