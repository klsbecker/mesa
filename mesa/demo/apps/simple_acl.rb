#!/usr/bin/env ruby

# Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
# SPDX-License-Identifier: MIT

require_relative 'libeasy/et'

$ts = get_test_setup("mesa_pc_b2b_2x")

$idx_tx = 0
$idx_rx = 1
$ace_id = 1

#---------- Configuration -----------------------------------------------------

test "conf" do
    # Set the default port action for the ingress port to be the drop action.
    # Any frame arriving on this port that doesn't match any ACE will be dropped.
    port = $ts.dut.port_list[$idx_tx]
    conf = $ts.dut.call("mesa_acl_port_conf_get", port)
    conf["action"]["port_action"] = "MESA_ACL_PORT_ACTION_FILTER"
    # empty port list = drop action
    conf["action"]["port_list"]   = ""
    $ts.dut.call("mesa_acl_port_conf_set", port, conf)

    # Add the correct rule to 
    # match : IPv4 + TCP + dport 80, ingress on port $idx_tx 
    # action : FILTER to $idx_rx (forward only to the rx port)
    ace = $ts.dut.call("mesa_ace_init", "MESA_ACE_TYPE_IPV4")
    ace["id"]        = $ace_id
    ace["port_list"] = port_idx_list_str([$idx_tx])

    ace["action"]["port_action"] = "MESA_ACL_PORT_ACTION_FILTER"
    ace["action"]["port_list"]   = port_idx_list_str([$idx_rx])

    # Match the transport proto to be TCP
    f = ace["frame"]["ipv4"]
    f["proto"]["value"] = 6
    f["proto"]["mask"]  = 0xff

    # Match the TCP dport to be 80
    f["dport"]["in_range"] = true
    f["dport"]["low"]      = 80
    f["dport"]["high"]     = 80

    $ts.dut.call("mesa_ace_add", 0, ace)
end

#---------- Frame testing -----------------------------------------------------

test "frame-io" do
    # Send IPv4 TCP frames with dport 70..90.
    (70..90).each do |dport|
        # Print the dport of the frame and the expected action  
        expected_rx = (dport == 80) ? [$idx_rx] : []
        t_i("TCP dport #{dport}, #{dport == 80 ? "forward to port #{$idx_rx}" : "drop"}")
        run_ef_tx_rx_cmd($ts, $idx_tx, expected_rx, "eth ipv4 tcp dport #{dport}")
    end
    
end

test_summary
