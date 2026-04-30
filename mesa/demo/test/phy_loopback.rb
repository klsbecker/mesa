#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'
$ts = get_test_setup("mesa_pc_b2b_2x")

#---------- Capabilities -----------------------------------------------------
check_capabilities do
    $ts.pc.p.each_index do |idx|
        c = $ts.dut.call "meba_capability", $ts.dut.p[idx], "MEPA_CAP_LOOPBACK"
        assert(c != 0, "phy loopback is not supported")
    end
end

$frame_smac    = "00:00:00:00:00:01"
$frame_dmac    = "00:00:00:00:00:02"

def lb_linkpartner(idx)
    frame_smac = "00:00:00:00:0#{idx}:01"

    cmd = "sudo ef -t 1000 name f#{idx} eth smac #{frame_smac} "
    cmd += "et 0x0800 data pattern cnt 64 "
    cmd += "tx #{$ts.pc.p[idx]} name f#{idx} "
    cmd += "rx #{$ts.pc.p[idx]} name f#{idx}"
    $ts.pc.try cmd
end

def lb_mac(idx)
    other_idx = (idx + 1) % 4

    frame_smac = "00:00:00:00:0#{other_idx}:01"

    cmd = "sudo ef -t 1000 name f#{other_idx} eth smac #{frame_smac} "
    cmd += "et 0x0800 data pattern cnt 64 "
    cmd += "tx #{$ts.pc.p[other_idx]} name f#{other_idx} "
    cmd += "rx #{$ts.pc.p[other_idx]} name f#{other_idx}"
    $ts.pc.try cmd
end

test "conf" do
    $ts.pc.p.each_index do |idx|
        bitmask = $ts.dut.call("meba_capability", $ts.dut.p[idx], "MEPA_CAP_LOOPBACK")

        for bit in 0..31
            case bitmask & (1 << bit)
            when 0x00001
                lb = $ts.dut.call "meba_phy_loopback_get", $ts.dut.p[idx]
                lb["far_end_ena"] = true
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb

                sleep 2
                lb_linkpartner(idx)

                lb["far_end_ena"] = false
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb
            when 0x00002
                lb = $ts.dut.call "meba_phy_loopback_get", $ts.dut.p[idx]
                lb["near_end_ena"] = true
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb

                sleep 2
                lb_mac(idx)

                lb["near_end_ena"] = false
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb

                # apparently some PHYs enables and disables autoneg when this is
                # enabled or disabled. meaning that we need to make sure that
                # the link is up before continue with the next test
                sleep 5
            when 0x00004
                # this needs a special cable so we ignore for now
            when 0x00008
            when 0x00010
            when 0x00020
            when 0x00040
            when 0x00080
            when 0x00100
            when 0x00200
                # this works by itself
                lb = $ts.dut.call "meba_phy_loopback_get", $ts.dut.p[idx]
                lb["qsgmii_pcs_tbi_ena"] = true
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb

                sleep 2
                lb_linkpartner(idx)

                lb["qsgmii_pcs_tbi_ena"] = false
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb
            when 0x00400
                # this works by itself
                lb = $ts.dut.call "meba_phy_loopback_get", $ts.dut.p[idx]
                lb["qsgmii_pcs_gmii_ena"] = true
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb

                sleep 2
                lb_mac(idx)

                lb["qsgmii_pcs_gmii_ena"] = false
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb
            when 0x00800
                # this works by itself
                lb = $ts.dut.call "meba_phy_loopback_get", $ts.dut.p[idx]
                lb["qsgmii_serdes_ena"] = true
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb

                sleep 3
                lb_linkpartner(idx)

                lb["qsgmii_serdes_ena"] = false
                $ts.dut.call "meba_phy_loopback_set", $ts.dut.p[idx], lb
            end
        end
    end
end
