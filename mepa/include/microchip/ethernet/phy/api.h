// Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
// SPDX-License-Identifier: MIT

#ifndef MICROCHIP_ETHERNET_PHY_API_H
#define MICROCHIP_ETHERNET_PHY_API_H

#pragma coverity compliance deviate                                            \
    "MISRA C-2023 Rule 17.1"                                                   \
    "stdarg.h required for va_list in mepa_trace_func_t callback interface"
#include <stdarg.h>
#include <microchip/ethernet/common.h>
#include <microchip/ethernet/phy/api/types.h>
#include <microchip/ethernet/phy/api/phy.h>
#include <microchip/ethernet/phy/api/phy_ts.h>
#include <microchip/ethernet/phy/api/phy_macsec.h>
#include <microchip/ethernet/phy/api/phy_tc10.h>
#include <microchip/ethernet/phy/api/phy_t1s.h>

#endif // MICROCHIP_ETHERNET_PHY_API_H
