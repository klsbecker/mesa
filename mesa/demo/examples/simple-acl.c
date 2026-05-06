// Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
// SPDX-License-Identifier: MIT

#include <unistd.h>
#include <stdio.h>
#include "cli.h"
#include "example.h"
#include "microchip/ethernet/switch/api.h"

#define ACE_ID_FWD  1 // Higher Priority: Forward TCP/80 to eport
#define ACE_ID_DROP 2 // Lower Priority: Drop everything else

static int acl_init(int argc, const char *argv[])
{
    mesa_port_no_t iport = ARGV_INT("iport", "Ingress Port");
    mesa_port_no_t eport = ARGV_INT("eport", "Egress Port / Port that receives TCP/80 frames");
    mesa_ace_t     ace;
    mesa_ace_frame_ipv4_t *ipv4 = &ace.frame.ipv4;

    EXAMPLE_BARRIER(argc);

    // ACE 1 (Higher Priority): forward to eport only IPv4 TCP dport 80
    RC(mesa_ace_init(NULL, MESA_ACE_TYPE_IPV4, &ace));
    ace.id = ACE_ID_FWD;
    mesa_port_list_set(&ace.port_list, iport, 1);
    ipv4->proto.value = 6;
    ipv4->proto.mask = 0xff;
    ipv4->dport.in_range = TRUE;
    ipv4->dport.low = 80;
    ipv4->dport.high = 80;
    ace.action.port_action = MESA_ACL_PORT_ACTION_REDIR;
    mesa_port_list_set(&ace.action.port_list, eport, 1);
    RC(mesa_ace_add(NULL, MESA_ACE_ID_LAST, &ace));

    // ACE 2 (Lower Priority): else drop all on iport
    RC(mesa_ace_init(NULL, MESA_ACE_TYPE_ANY, &ace));
    ace.id = ACE_ID_DROP;
    mesa_port_list_set(&ace.port_list, iport, 1);
    ace.action.port_action = MESA_ACL_PORT_ACTION_FILTER;
    RC(mesa_ace_add(NULL, MESA_ACE_ID_LAST, &ace));

    return 0;
}

static int acl_uninit(void)
{
    RC(mesa_ace_del(NULL, 1));
    RC(mesa_ace_del(NULL, 2));
    return 0;
}

static const char *help_txt =
    " Simple ACL example. \n"
    "\n"
    "A single ACE forwards IPv4 TCP frames with destination port 80 to the egress port.\n"
    "Any other frame will be dropped by default.\n";

static const char *acl_help(void) { return help_txt; }

EXAMPLE(simple_acl, acl_init, NULL, acl_uninit, acl_help);
