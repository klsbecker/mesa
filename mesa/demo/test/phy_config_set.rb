#!/usr/bin/env ruby

# Copyright (c) 2004-2026 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'
$ts = get_test_setup("mesa_pc_b2b_2x")

#---------- Capabilities -----------------------------------------------------
$frame_smac    = "00:00:00:00:00:01"
$frame_dmac    = "00:00:00:00:00:02"

#---------- Capabilities -----------------------------------------------------
check_capabilities do
    $ts.dut.p.each_index do |idx|
        s = $ts.dut.try_ignore "meba_phy_status_poll", $ts.dut.p[idx]
        assert(s != nil, "There is no PHY on the port")
    end
end

def fail_send_traffic(idx)
    frame_smac = "00:00:00:00:0#{idx}:01"

    # traffic send on this port should not go anywhere
    cmd = "ef -t 1000 name f#{idx} eth smac #{frame_smac} "
    cmd += "et 0x0800 data pattern cnt 64 "
    cmd += "tx #{$ts.pc.p[idx]} name f#{idx} "
    $ts.dut.p.each_index do |i|
        next if i == idx
        cmd += "rx #{$ts.pc.p[i]} "
    end
    $ts.pc.try cmd

    other_idx = (idx + 1) % $ts.pc.p.length()

    frame_smac = "00:00:00:00:0#{other_idx}:01"

    # traffic send on other ports should go to all the ports except to the idx
    # port
    cmd = "ef -t 1000 name f#{other_idx} eth smac #{frame_smac} "
    cmd += "et 0x0800 data pattern cnt 64 "
    cmd += "tx #{$ts.pc.p[other_idx]} name f#{other_idx} "
    $ts.dut.p.each_index do |i|
        next if i == other_idx
        if i == idx
            cmd += "rx #{$ts.pc.p[i]} "
        else
            cmd += "rx #{$ts.pc.p[i]} name f#{other_idx} "
        end

    end
    $ts.pc.try cmd
end

def send_traffic(idx)
    frame_smac = "00:00:00:00:0#{idx}:01"

    # traffic send on this port should not go anywhere
    cmd = "ef -t 1000 name f#{idx} eth smac #{frame_smac} "
    cmd += "et 0x0800 data pattern cnt 64 "
    cmd += "tx #{$ts.pc.p[idx]} name f#{idx} "
    $ts.dut.p.each_index do |i|
        next if i == idx
        cmd += "rx #{$ts.pc.p[i]} name f#{idx} "
    end
    $ts.pc.try cmd

    other_idx = (idx + 1) % $ts.pc.p.length()

    frame_smac = "00:00:00:00:0#{other_idx}:01"

    # traffic send on other ports should go to all the ports except to the idx
    # port
    cmd = "ef -t 1000 name f#{other_idx} eth smac #{frame_smac} "
    cmd += "et 0x0800 data pattern cnt 64 "
    cmd += "tx #{$ts.pc.p[other_idx]} name f#{other_idx} "
    $ts.dut.p.each_index do |i|
        next if i == other_idx
        cmd += "rx #{$ts.pc.p[i]} name f#{other_idx} "
    end
    $ts.pc.try cmd
end

def wait_for_link(idx)
    loop do
      status = $ts.dut.call "meba_phy_status_poll", $ts.dut.p[idx]
      if status["link"] == true
          return status
      end
      sleep 1
    end
end

test "admin.enable" do
    $ts.dut.p.each_index do |idx|
        conf = $ts.dut.call "meba_phy_conf_get", $ts.dut.p[idx]

        conf["admin"]["enable"] = false
        $ts.dut.call "meba_phy_conf_set", $ts.dut.p[idx], conf

        fail_send_traffic(idx)

        conf["admin"]["enable"] = true
        $ts.dut.call "meba_phy_conf_set", $ts.dut.p[idx], conf

        wait_for_link(idx)

        sleep 1
        send_traffic(idx)
    end
end

test "force speed and duplex" do
    $speed_list = [{ speed: "MESA_SPEED_100M",    dpx: true},
                   { speed: "MESA_SPEED_100M",    dpx: false},
                   { speed: "MESA_SPEED_10M",     dpx: true},
                   { speed: "MESA_SPEED_10M",     dpx: false}]

    $ts.dut.p.each_index do |idx|
        $speed_list.each do |spd_entry|
            conf = $ts.dut.call "meba_phy_conf_get", $ts.dut.p[idx]
            conf["speed"] = spd_entry[:speed]
            conf["fdx"] = spd_entry[:dpx]
            $ts.dut.call "meba_phy_conf_set", $ts.dut.p[idx], conf

            wait_for_link(idx)

            conf = $ts.dut.call "mesa_port_conf_get", $ts.dut.p[idx]
            conf["speed"] = spd_entry[:speed]
            conf["fdx"] = spd_entry[:dpx]
            $ts.dut.call "mesa_port_conf_set", $ts.dut.p[idx], conf

            sleep 1

            send_traffic(idx)
        end
    end
end

test "restore the speed to default" do
    $ts.dut.p.each_index do |idx|
        conf = $ts.dut.call "meba_phy_conf_get", $ts.dut.p[idx]
        conf["speed"] = "MESA_SPEED_AUTO"
        $ts.dut.call "meba_phy_conf_set", $ts.dut.p[idx], conf

        wait_for_link(idx)

        conf = $ts.dut.call "mesa_port_conf_get", $ts.dut.p[idx]
        conf["speed"] = "MESA_SPEED_1G"
        $ts.dut.call "mesa_port_conf_set", $ts.dut.p[idx], conf

        sleep 1
        send_traffic(idx)
    end
end

test "aneg speed" do
    $speed_list = [{ adv_dis: 0x00000010, speed: "MESA_SPEED_100M", dpx: true},
                   { adv_dis: 0x00000011, speed: "MESA_SPEED_100M", dpx: true},
                   { adv_dis: 0x00000012, speed: "MESA_SPEED_100M", dpx: false},
                   { adv_dis: 0x00000050, speed: "MESA_SPEED_10M", dpx: true},
                   { adv_dis: 0x00000051, speed: "MESA_SPEED_10M", dpx: true},
                   { adv_dis: 0x00000052, speed: "MESA_SPEED_10M", dpx: false}]

    $ts.dut.p.each_index do |idx|
        next if idx != 0

        $speed_list.each do |spd_entry|
            conf = $ts.dut.call "meba_phy_conf_get", $ts.dut.p[idx]
            conf["adv_dis"] = spd_entry[:adv_dis]
            $ts.dut.call "meba_phy_conf_set", $ts.dut.p[idx], conf

            wait_for_link(idx)

            conf = $ts.dut.call "mesa_port_conf_get", $ts.dut.p[idx]
            conf["speed"] = spd_entry[:speed]
            conf["fdx"] = spd_entry[:dpx]
            $ts.dut.call "mesa_port_conf_set", $ts.dut.p[idx], conf

            sleep 1

            send_traffic(idx)
        end
    end
end
