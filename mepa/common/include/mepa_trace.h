// Copyright (c) 2004-2021 Microchip Technology Inc. and its subsidiaries.
// SPDX-License-Identifier: MIT

#ifndef MICROCHIP_ETHERNET_PHY_API_TRACE_H
#define MICROCHIP_ETHERNET_PHY_API_TRACE_H

#include "mepa_driver.h"

#define T_N(grp, format, ...) MEPA_trace((grp), MEPA_TRACE_LVL_NOISE, __FUNCTION__, __LINE__, __FILE__, format, ##__VA_ARGS__);
#define T_D(grp, format, ...) MEPA_trace((grp), MEPA_TRACE_LVL_DEBUG, __FUNCTION__, __LINE__, __FILE__, format, ##__VA_ARGS__);
#define T_I(grp, format, ...) MEPA_trace((grp), MEPA_TRACE_LVL_INFO, __FUNCTION__, __LINE__, __FILE__, format, ##__VA_ARGS__);
#define T_W(grp, format, ...) MEPA_trace((grp), MEPA_TRACE_LVL_WARNING, __FUNCTION__, __LINE__, __FILE__, format, ##__VA_ARGS__);
#define T_E(grp, format, ...) MEPA_trace((grp), MEPA_TRACE_LVL_ERROR, __FUNCTION__, __LINE__, __FILE__, format, ##__VA_ARGS__);

#endif /**< MICROCHIP_ETHERNET_PHY_API_TRACE_H */
