#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'

$ts = get_test_setup("mesa_pc_b2b_2x")

$idx_tx = 0
$idx_rx = 1

# Do the init of the simple_acl example.
test "init" do
    $ts.dut.run("mesa-cmd example init simple_acl iport #{$ts.dut.p[$idx_tx]} eport #{$ts.dut.p[$idx_rx]}")
end

test "frame-io" do
    # Send IPv4 over TCP frames with dport 70..90.
    (70..90).each do |dport|
        # Print the dport of the frame and the expected action  
        expected_rx = (dport == 80) ? [$idx_rx] : []
        t_i("TCP dport #{dport}, #{dport == 80 ? "forward to port #{$idx_rx}" : "drop"}")
        run_ef_tx_rx_cmd($ts, $idx_tx, expected_rx, "eth ipv4 tcp dport #{dport}")
    end
end

# Do the uninit and check that ACL actions have been cleared.
test "uninit" do
    $ts.dut.run("mesa-cmd example uninit")
    conf = $ts.dut.call("mesa_acl_port_conf_get", $ts.dut.p[$idx_tx])
    if conf["action"]["port_action"] != "MESA_ACL_PORT_ACTION_NONE"
        t_e("Port ACL action not restored after uninit")
    end
end

test_summary