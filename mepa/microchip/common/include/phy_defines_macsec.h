// Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
// SPDX-License-Identifier: MIT

#ifndef PHY_DEFINES_MACSEC_H
#define PHY_DEFINES_MACSEC_H

#include <phy_defines.h>

#define MMD_MS_REAL_DEV 3U
#define MMD_FCB     MMD_MS_REAL_DEV
#define MMD_LINE_HOST   MMD_MS_REAL_DEV

#define MCHP_MAC_FCB_CONFIG            0U
#define MCHP_MAC_FCB_STATUS            18U

// MCHP_MAC_FCB_FC_ENA_CFG
static inline uint32_t MCHP_MAC_FCB_FC_ENA_CFG(uint32_t b)
{
    return ((b) + MCHP_MAC_FCB_CONFIG);
}
#define MCHP_FCB_ENA_CFG_RX_ENA     BIT32(4)
#define MCHP_FCB_ENA_CFG_TX_ENA         BIT32(0)

// MCHP_MAC_FCB_FC_MODE_CFG
static inline uint32_t MCHP_MAC_FCB_FC_MODE_CFG(uint32_t b)
{
    return ((b) + MCHP_MAC_FCB_CONFIG + 2U);
}
#define MCHP_FCB_MODE_CFG_TX_CTRL_QUEUE_ENA     BIT32(20)

// MCHP_MAC_FCB_PPM_RATE_ADAPT_THRESH_CFG
static inline uint32_t MCHP_MAC_FCB_PPM_RATE_ADAPT_THRESH_CFG(uint32_t b)
{
    return ((b) + MCHP_MAC_FCB_CONFIG + 4U);
}
static inline uint32_t MCHP_FCB_PPM_RATE_ADAPT_THRESH_CFG_RX_THRESH(uint32_t x)
{
    return (x << 20U);
}
static inline uint32_t MCHP_FCB_PPM_RATE_ADAPT_THRESH_CFG_TX_OFFSET(uint32_t x)
{
    return (x << 16U);
}
// MCHP_MAC_FCB_FC_READ_THRESH_CFG
static inline uint32_t MCHP_MAC_FCB_FC_READ_THRESH_CFG(uint32_t b)
{
    return ((b) + MCHP_MAC_FCB_CONFIG + 14U);
}
static inline uint32_t MCHP_FCB_FC_READ_THRESH_CFG_RX_THRESH(uint32_t x)
{
    return ((x) << 16U);
}
static inline uint32_t MCHP_FCB_FC_READ_THRESH_CFG_TX_THRESH(uint32_t x)
{
    return (x);
}

// MCHP_MAC_FCB_STICKY_MASK
static inline uint32_t MCHP_FCB_FC_STICKY_MASK(uint32_t b)
{
    return ((b) + MCHP_MAC_FCB_STATUS + 2U);
}
#define MCHP_FCB_RX_OFLOW_DROP_STICKY_MASK      BIT32(20)
#define MCHP_FCB_TX_DATA_Q_UFLOW_DROP_STICKY_MASK   BIT32(19)
#define MCHP_FCB_TX_CTRL_Q_UFLOW_DROP_STICKY_MASK   BIT32(17)
#define MCHP_FCB_XON_PAUSE_GEN_STICKY_MASK      BIT32(1)
#define MCHP_FCB_STICKY_MASK_SET    \
            (MCHP_FCB_XON_PAUSE_GEN_STICKY_MASK | \
             MCHP_FCB_TX_CTRL_Q_UFLOW_DROP_STICKY_MASK | \
             MCHP_FCB_TX_DATA_Q_UFLOW_DROP_STICKY_MASK | \
             MCHP_FCB_RX_OFLOW_DROP_STICKY_MASK)

#define MCHP_LH_MAC_CONFIG      0x0U
#define MCHP_LH_MAC_PAUSE_CFG       0x16U

// LINE_MAC_MAC_ENA_CFG/HOST_MAC_MAC_ENA_CFG
static inline uint32_t MCHP_LH_MAC_ENA_CFG(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG);
}
#define MCHP_LH_MAC_CFG_ENA_CFG_TX_ENA         BIT32(20)
#define MCHP_LH_MAC_CFG_ENA_CFG_RX_ENA         BIT32(16)
#define MCHP_LH_MAC_CFG_ENA_CFG_TX_SW_RST      BIT32(12)
#define MCHP_LH_MAC_CFG_ENA_CFG_RX_SW_RST      BIT32(8)
#define MCHP_LH_MAC_CFG_ENA_CFG_TX_CLK_ENA     BIT32(4)
#define MCHP_LH_MAC_CFG_ENA_CFG_RX_CLK_ENA     BIT32(0)
#define MCHP_LH_MAC_MAC_ENA_CFG_MS_RST       \
            (MCHP_LH_MAC_CFG_ENA_CFG_RX_CLK_ENA | \
             MCHP_LH_MAC_CFG_ENA_CFG_TX_CLK_ENA | \
             MCHP_LH_MAC_CFG_ENA_CFG_RX_SW_RST | \
             MCHP_LH_MAC_CFG_ENA_CFG_TX_SW_RST | \
             MCHP_LH_MAC_CFG_ENA_CFG_RX_ENA | \
             MCHP_LH_MAC_CFG_ENA_CFG_TX_ENA)

#define MCHP_LH_MAC_MAC_ENA_CFG_MS_EN        \
            (MCHP_LH_MAC_CFG_ENA_CFG_RX_CLK_ENA | \
             MCHP_LH_MAC_CFG_ENA_CFG_TX_CLK_ENA | \
             MCHP_LH_MAC_CFG_ENA_CFG_RX_ENA | \
             MCHP_LH_MAC_CFG_ENA_CFG_TX_ENA)

static inline uint32_t MCHP_LH_MAC_MODE_CFG(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG + 2U);
}
#define MCHP_LH_MAC_MODE_UNDERSIZED_FRAME_DROP_DIS      BIT32(1)
#define MCHP_LH_MAC_MODE_DISABLE_DIC                    BIT32(0)

static inline uint32_t MCHP_LH_MAC_MODE_FORCE_CW_UPDATE_INTERVAL(uint32_t x)
{
    return ((uint32_t)(x) << 20U);
}
static inline uint32_t MCHP_LH_MAC_MAXLEN_CFG(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG + 4U);
}

#define MCHP_LH_MAC_MAXLEN_TAG_CHK     BIT32(16)

static inline uint32_t MCHP_LH_MAC_NUM_TAGS_CFG(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG + 6U);
}
static inline uint32_t MCHP_LH_MAC_TAGS_CFG0(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG + 8U);
}
static inline uint32_t MCHP_LH_MAC_TAGS_CFG1(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG + 10U);
}
static inline uint32_t MCHP_LH_MAC_TAGS_CFG2(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG + 12U);
}
static inline uint32_t MCHP_LH_MAC_TAGS_CFG_TAG_ID(uint32_t x)
{
    return ((x) << 16U);
}
#define MCHP_LH_MAC_TAGS_CFG_TAG_ENA           BIT(4)
static inline uint32_t MCHP_LH_MAC_TAGS_CFG_SET(uint32_t x)
{
    return (MCHP_LH_MAC_TAGS_CFG_TAG_ID(x) | MCHP_LH_MAC_TAGS_CFG_TAG_ENA);
}
static inline uint32_t MCHP_LH_MAC_ADV_CHK_CFG(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG + 14U);
}
#define MCHP_LH_MAC_ADV_CHK_EXT_EOP_CHK_ENA     BIT32(24)
#define MCHP_LH_MAC_ADV_CHK_EXT_SOP_CHK_ENA     BIT32(20)
#define MCHP_LH_MAC_ADV_CHK_SFD_CHK_ENA         BIT32(16)
#define MCHP_LH_MAC_ADV_CHK_PRM_CHK_ENA         BIT32(8)
#define MCHP_LH_MAC_ADV_CHK_OOR_ERR_ENA         BIT32(4)
#define MCHP_LH_MAC_ADV_CHK_INR_ERR_ENA         BIT32(0)
#define MCHP_LH_MAC_MAC_ADV_CHK_INIT         \
            (MCHP_LH_MAC_ADV_CHK_INR_ERR_ENA | \
             MCHP_LH_MAC_ADV_CHK_OOR_ERR_ENA | \
             MCHP_LH_MAC_ADV_CHK_PRM_CHK_ENA | \
             MCHP_LH_MAC_ADV_CHK_SFD_CHK_ENA | \
             MCHP_LH_MAC_ADV_CHK_EXT_SOP_CHK_ENA | \
             MCHP_LH_MAC_ADV_CHK_EXT_EOP_CHK_ENA)

static inline uint32_t MCHP_LH_MAC_LFS_CFG(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG + 16U);
}
static inline uint32_t MCHP_LH_MAC_PKTINF_CFG(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_CONFIG + 20U);
}
#define MCHP_LH_MAC_PKTINF_CFG_ENABLE_TX_PADDING    BIT32(25)
#define MCHP_LH_MAC_PKTINF_CFG_RF_RELAY_ENA     BIT32(24)
#define MCHP_LH_MAC_PKTINF_CFG_LF_RELAY_ENA     BIT32(20)
#define MCHP_LH_MAC_PKTINF_CFG_LPI_RELAY_ENA        BIT32(16)
#define MCHP_LH_MAC_PKTINF_CFG_INSERT_PREAMBLE_ENA  BIT32(12)
#define MCHP_LH_MAC_PKTINF_CFG_STRIP_PREAMBLE_ENA       BIT32(8)
#define MCHP_LH_MAC_PKTINF_CFG_INSERT_FCS_ENA           BIT32(4)
#define MCHP_LH_MAC_PKTINF_CFG_STRIP_FCS_ENA        BIT32(0)

#define MCHP_LH_MAC_PKTINF_CFG_INIT  \
            (MCHP_LH_MAC_PKTINF_CFG_STRIP_FCS_ENA | \
             MCHP_LH_MAC_PKTINF_CFG_INSERT_FCS_ENA | \
             MCHP_LH_MAC_PKTINF_CFG_STRIP_PREAMBLE_ENA | \
             MCHP_LH_MAC_PKTINF_CFG_INSERT_PREAMBLE_ENA | \
             MCHP_LH_MAC_PKTINF_CFG_LPI_RELAY_ENA | \
             MCHP_LH_MAC_PKTINF_CFG_LF_RELAY_ENA | \
             MCHP_LH_MAC_PKTINF_CFG_RF_RELAY_ENA)

static inline uint32_t MCHP_LH_MAC_PAUSE_TX_FRAME_CTL(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_PAUSE_CFG + 0U);
}
static inline uint32_t MCHP_LH_MAC_TX_PAUSE_VALUE(uint32_t x)
{
    return ((x) << 16U);
}

static inline uint32_t MCHP_LH_MAC_PAUSE_TX_FRAME_CTL_2(uint32_t b)
{
    return ((b) + MCHP_LH_MAC_PAUSE_CFG + 2U);
}

#endif //PHY_DEFINES_MACSEC_H
