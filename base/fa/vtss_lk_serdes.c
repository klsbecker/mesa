// Copyright (c) 2004-2025 Microchip Technology Inc. and its subsidiaries.
// SPDX-License-Identifier: MIT

#define VTSS_TRACE_GROUP VTSS_TRACE_GROUP_PORT
#include "vtss_fa_cil.h"

#if defined(VTSS_ARCH_LAIKA)

vtss_rc vtss_fa_port2sd(vtss_state_t *vtss_state, vtss_port_no_t port_no, u32 *sd_indx, u32 *sd_type)
{
    *sd_indx = 0;
    *sd_type = FA_SERDES_TYPE_UNKNOWN;

    u32 p = VTSS_CHIP_PORT(port_no);
    if (p > 31) {
        return VTSS_RC_ERROR;
    }

    switch (vtss_state->port.conf[port_no].if_type) {
    case VTSS_PORT_INTERFACE_QSGMII:
    case VTSS_PORT_INTERFACE_QXGMII:
        *sd_indx = (p / 4) * 2;
        VTSS_N("(QUAD 1G/2G5 SD) QxGMII p:%d SD10G_LANE index: %d", p, *sd_indx);
        break;
    default:
        if (p & 0x01) {
            return VTSS_RC_ERROR;
        }
        *sd_indx = p / 2;
    }

    *sd_type = FA_SERDES_TYPE_10G;
    return VTSS_RC_OK;
}

/* Returns index 0-15 for 10G ports for LK */
u32 vtss_fa_port2sd_indx(vtss_state_t *vtss_state, vtss_port_no_t port_no)
{
    u32 sd_indx = 0U, sd_type;
    (void)vtss_fa_port2sd(vtss_state, port_no, &sd_indx, &sd_type);
    return sd_indx;
}

/* Returns serdes LANE index 0-15 for LK */
u32 vtss_fa_sd_lane_indx(vtss_state_t *vtss_state, vtss_port_no_t port_no)
{
    u32 indx = 0U, type;

    (void)vtss_fa_port2sd(vtss_state, port_no, &indx, &type);
    return indx;
}

vtss_rc vtss_fa_sd_cfg(vtss_state_t *vtss_state, vtss_port_no_t port_no, vtss_serdes_mode_t mode)
{
    return VTSS_RC_OK;
}

vtss_rc vtss_fa_serdes_init(vtss_state_t *vtss_state) { return VTSS_RC_OK; }

vtss_rc fa_serdes_ctle_adjust(vtss_state_t *vtss_state,
                              lmu_ss_t     *ss,
                              u32           port_no,
                              BOOL          ro,
                              u32          *vga,
                              u32          *eqr,
                              u32          *eqc)
{
    return VTSS_RC_OK;
}

vtss_rc fa_debug_serdes_set(vtss_state_t                         *vtss_state,
                            const vtss_port_no_t                  port_no,
                            const vtss_port_serdes_debug_t *const conf)

{
    return VTSS_RC_OK;
}

vtss_rc fa_debug_serdes_get(vtss_state_t                   *vtss_state,
                            const vtss_port_no_t            port_no,
                            vtss_port_serdes_debug_t *const conf)
{
    return VTSS_RC_OK;
}

vtss_rc fa_debug_chip_serdes(vtss_state_t                  *vtss_state,
                             lmu_ss_t                      *ss,
                             const vtss_debug_info_t *const info,
                             vtss_port_no_t                 port_no)
{
    return VTSS_RC_OK;
}

#endif /* VTSS_ARCH_LAIKA */
