// Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
// SPDX-License-Identifier: MIT

#ifndef MEPA_KSZ9031_PRIVATE_H
#define MEPA_KSZ9031_PRIVATE_H

#include <microchip/ethernet/phy/api.h>

#define KSZ9131RN_MMD_COMMON_CTRL_REG   2
#define KSZ9131RN_RXC_DLL_CTRL          76
#define KSZ9131RN_TXC_DLL_CTRL          77
#define KSZ9131RN_DLL_DISABLE_DELAY     BIT(12)
#define KSZ9131RN_DLL_ENABLE_DELAY      0U
#define KSZ9131RN_DLL_MASK              BIT(12)

#endif
