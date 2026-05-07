// Copyright (c) 2004-2020 Microchip Technology Inc. and its subsidiaries.
// SPDX-License-Identifier: MIT

#include <unistd.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

#include <microchip/ethernet/phy/api.h>
#include <mepa_driver.h>
#include <mepa_ts_driver.h>

#include "phy_driver.h"
#include <phy_lib.h>

#define KSZ9031_PHY_CHIPID 0x00221622
#define KSZ9131_PHY_CHIPID 0x00221642

#define AUTONEG_ENABLE      0x01

#define MII_KSZ9031RN_FLP_BURST_TX_LO   3
#define MII_KSZ9031RN_FLP_BURST_TX_HI   4

typedef struct {
    unsigned autoneg;
    /* The most recently read link state */
    unsigned link;
    unsigned autoneg_complete;
    int speed;
    BOOL duplex;
} phy_device;

typedef struct {
    phy_device    phydev;
} priv_data_t;

/* Center KSZ9031RNX FLP timing at 16ms. */
static mepa_rc ksz_restart_aneg(mepa_device_t *dev)
{
    return phy_reg_modify(dev, MII_BMCR, BMCR_ISOLATE | BMCR_ANENABLE | BMCR_ANRESTART,
                          BMCR_ANENABLE | BMCR_ANRESTART);
}

static mepa_rc ksz_center_flp_timing(mepa_device_t  *dev)
{
    mepa_rc rc;

    rc = phy_mmd_reg_wr(dev, 0, MII_KSZ9031RN_FLP_BURST_TX_HI, 0x0006);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    rc = phy_mmd_reg_wr(dev, 0, MII_KSZ9031RN_FLP_BURST_TX_LO, 0x1A80);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    return ksz_restart_aneg(dev);
}

/**
 * genphy_update_link - update link status in @phydev
 * @phydev: target phy_device struct
 *
 * Description: Update the value in phydev->link to reflect the
 *   current link value.  In order to do this, we need to read
 *   the status register twice, keeping the second value.
 */
static mepa_rc ksz_update_link(mepa_device_t  *dev)
{
    phy_device  *phydev = &((priv_data_t *)dev->data)->phydev;
    uint16_t status = 0, bmcr;
    mepa_rc rc;

    rc = phy_reg_rd(dev, MII_BMCR, &bmcr);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    /* Autoneg is being started, therefore disregard BMSR value and
     * report link as down.
     */
    if (bmcr & BMCR_ANRESTART) {
        goto done;
    }

    /* Read link and autonegotiation status */
    rc = phy_reg_rd(dev, MII_BMSR, &status);
    if (rc != MEPA_RC_OK) {
        return rc;
    }
done:
    phydev->link = status & BMSR_LSTATUS ? 1 : 0;
    phydev->autoneg_complete = status & BMSR_ANEGCOMPLETE ? 1 : 0;

    /* Consider the case that autoneg was started and "aneg complete"
     * bit has been reset, but "link up" bit not yet.
     */
    if (phydev->autoneg == AUTONEG_ENABLE && !phydev->autoneg_complete) {
        phydev->link = 0;
    }

    return MEPA_RC_OK;
}

static mepa_rc ksz_read_status(mepa_device_t  *dev)
{
    phy_device  *phydev = &((priv_data_t *)dev->data)->phydev;
    int old_link = phydev->link;
    uint16_t bmcr;
    mepa_rc rc;

    /* Update the link, but return if there was an error */
    rc = ksz_update_link(dev);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    /* why bother the PHY if nothing can have changed */
    if (phydev->autoneg == AUTONEG_ENABLE && old_link && phydev->link) {
        return 0;
    }

    phydev->speed = MEPA_SPEED_UNDEFINED;
    phydev->duplex = 1U;

    rc = phy_reg_rd(dev, MII_BMCR, &bmcr);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    if (bmcr & BMCR_FULLDPLX) {
        phydev->duplex = 1U;
    } else {
        phydev->duplex = 0U;
    }

    if (bmcr & BMCR_SPEED1000) {
        phydev->speed = MEPA_SPEED_1G;
    } else if (bmcr & BMCR_SPEED100) {
        phydev->speed = MEPA_SPEED_100M;
    } else {
        phydev->speed = MEPA_SPEED_10M;
    }

    return MEPA_RC_OK;
}

static mepa_rc ksz_poll(mepa_device_t *dev, mepa_status_t *status)
{
    phy_device *phydev = &((priv_data_t *)dev->data)->phydev;
    mepa_rc rc;

    T_D("Enter  port_no %u", dev->numeric_handle);

    rc = ksz_read_status(dev);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    status->link = phydev->link;
    status->speed = phydev->speed;
    status->fdx = phydev->duplex;

    return MEPA_RC_OK;
}

static mepa_rc ksz_conf_set(mepa_device_t      *dev,
                            const mepa_conf_t  *config)
{
    return ksz_center_flp_timing(dev);
}

static mepa_device_t *ksz_probe(mepa_driver_t                       *drv,
                                const mepa_callout_t    MEPA_SHARED_PTR *callout,
                                struct mepa_callout_ctx MEPA_SHARED_PTR *callout_ctx,
                                struct mepa_board_conf              *board_conf)
{
    mepa_device_t *dev;

    dev = mepa_create_int(drv, callout, callout_ctx, board_conf, sizeof(priv_data_t));
    if (!dev) {
        return 0;
    }

    return dev;
}

static mepa_rc ksz_status_1g_get(mepa_device_t *dev, mesa_phy_status_1g_t *status)
{
    return MEPA_RC_OK;
}

static mepa_rc ksz_1g_if_get(mepa_device_t *dev, mesa_port_speed_t speed,
                             mesa_port_interface_t *mac_if)
{

    *mac_if = MESA_PORT_INTERFACE_GMII;

    return MEPA_RC_OK;
}


static mepa_rc ksz_delete(mepa_device_t *dev)
{
    return mepa_delete_int(dev);
}

static uint32_t ksz_capability(mepa_device_t *dev, uint32_t capability)
{
    /* As this driver doesn't implement the mepa_driver_phy_info_get then we
     * don't need to return any capabilities. This needs to be extended once we
     * add new capabilities
     */
    return 0;
}

static mepa_rc ksz9131_rgmii_if_get(mepa_device_t *dev, mesa_port_speed_t speed,
                                    mesa_port_interface_t *mac_if)
{
    u16 rxcdll_val, txcdll_val;
    mepa_rc rc;

    rc = phy_mmd_reg_rd(dev, KSZ9131RN_MMD_COMMON_CTRL_REG, KSZ9131RN_RXC_DLL_CTRL,
                        &rxcdll_val);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    rc = phy_mmd_reg_rd(dev, KSZ9131RN_MMD_COMMON_CTRL_REG, KSZ9131RN_TXC_DLL_CTRL,
                        &txcdll_val);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    if ((rxcdll_val & KSZ9131RN_DLL_DISABLE_DELAY) && (txcdll_val & KSZ9131RN_DLL_DISABLE_DELAY)) {
        *mac_if = MESA_PORT_INTERFACE_RGMII;
    } else if (!(rxcdll_val & KSZ9131RN_DLL_DISABLE_DELAY) && (txcdll_val & KSZ9131RN_DLL_DISABLE_DELAY)) {
        *mac_if = MESA_PORT_INTERFACE_RGMII_RXID;
    } else if ((rxcdll_val & KSZ9131RN_DLL_DISABLE_DELAY) && !(txcdll_val & KSZ9131RN_DLL_DISABLE_DELAY)) {
        *mac_if = MESA_PORT_INTERFACE_RGMII_TXID;
    } else {
        *mac_if = MESA_PORT_INTERFACE_RGMII_ID;
    }

    return MEPA_RC_OK;
}

static mepa_rc ksz_config_rgmii_delay(mepa_device_t *dev, mesa_port_interface_t mac_if)
{
    u16 rxcdll_val, txcdll_val;
    mepa_rc rc;

    switch (mac_if) {
    case MESA_PORT_INTERFACE_RGMII:
        rxcdll_val = KSZ9131RN_DLL_DISABLE_DELAY;
        txcdll_val = KSZ9131RN_DLL_DISABLE_DELAY;
        break;
    case MESA_PORT_INTERFACE_RGMII_ID:
        rxcdll_val = KSZ9131RN_DLL_ENABLE_DELAY;
        txcdll_val = KSZ9131RN_DLL_ENABLE_DELAY;
        break;
    case MESA_PORT_INTERFACE_RGMII_RXID:
        rxcdll_val = KSZ9131RN_DLL_ENABLE_DELAY;
        txcdll_val = KSZ9131RN_DLL_DISABLE_DELAY;
        break;
    case MESA_PORT_INTERFACE_RGMII_TXID:
        rxcdll_val = KSZ9131RN_DLL_DISABLE_DELAY;
        txcdll_val = KSZ9131RN_DLL_ENABLE_DELAY;
        break;
    default:
        return MEPA_RC_ERROR;
    }

    rc = phy_mmd_reg_modify(dev, KSZ9131RN_MMD_COMMON_CTRL_REG,
                            KSZ9131RN_RXC_DLL_CTRL,
                            KSZ9131RN_DLL_MASK, rxcdll_val);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    rc = phy_mmd_reg_modify(dev, KSZ9131RN_MMD_COMMON_CTRL_REG,
                            KSZ9131RN_TXC_DLL_CTRL,
                            KSZ9131RN_DLL_MASK, txcdll_val);
    if (rc != MEPA_RC_OK) {
        return rc;
    }

    return MEPA_RC_OK;
}

static mepa_rc ksz9131_rgmii_if_set(mepa_device_t *dev, mepa_port_interface_t mac_if)
{
    if (mac_if != MESA_PORT_INTERFACE_RGMII &&
        mac_if != MESA_PORT_INTERFACE_RGMII_ID &&
        mac_if != MESA_PORT_INTERFACE_RGMII_RXID &&
        mac_if != MESA_PORT_INTERFACE_RGMII_TXID) {
        return MEPA_RC_ERROR;
    }

    return ksz_config_rgmii_delay(dev, mac_if);
}

mepa_drivers_t mepa_ksz9031_driver_init(void)
{
    mepa_drivers_t res;
    static mepa_driver_t ksz_drivers[2] = {};

    ksz_drivers[0].id = KSZ9031_PHY_CHIPID;
    ksz_drivers[0].mask = 0xfffffff0;
    ksz_drivers[0].mepa_driver_delete = ksz_delete;
    ksz_drivers[0].mepa_driver_reset = NULL;
    ksz_drivers[0].mepa_driver_poll = ksz_poll;
    ksz_drivers[0].mepa_driver_conf_set = ksz_conf_set;
    ksz_drivers[0].mepa_driver_if_get = ksz_1g_if_get;
    ksz_drivers[0].mepa_driver_power_set = NULL;
    ksz_drivers[0].mepa_driver_cable_diag_start = NULL;
    ksz_drivers[0].mepa_driver_cable_diag_get = NULL;
    ksz_drivers[0].mepa_driver_media_set = NULL;
    ksz_drivers[0].mepa_driver_probe = ksz_probe;
    ksz_drivers[0].mepa_driver_aneg_status_get = ksz_status_1g_get;
    ksz_drivers[0].mepa_driver_capability = ksz_capability;

    ksz_drivers[1].id = KSZ9131_PHY_CHIPID;
    ksz_drivers[1].mask = 0xfffffff0;
    ksz_drivers[1].mepa_driver_delete = ksz_delete;
    ksz_drivers[1].mepa_driver_reset = NULL;
    ksz_drivers[1].mepa_driver_poll = ksz_poll;
    ksz_drivers[1].mepa_driver_conf_set = ksz_conf_set;
    ksz_drivers[1].mepa_driver_if_set = ksz9131_rgmii_if_set;
    ksz_drivers[1].mepa_driver_if_get = ksz9131_rgmii_if_get;
    ksz_drivers[1].mepa_driver_power_set = NULL;
    ksz_drivers[1].mepa_driver_cable_diag_start = NULL;
    ksz_drivers[1].mepa_driver_cable_diag_get = NULL;
    ksz_drivers[1].mepa_driver_media_set = NULL;
    ksz_drivers[1].mepa_driver_probe = ksz_probe;
    ksz_drivers[1].mepa_driver_aneg_status_get = ksz_status_1g_get;
    ksz_drivers[1].mepa_driver_capability = ksz_capability;

    res.phy_drv = ksz_drivers;
    res.count = 2;

    return res;
}
