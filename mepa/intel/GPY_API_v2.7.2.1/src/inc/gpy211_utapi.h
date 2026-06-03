#ifndef _GPY2XX_UTAPI_H_
#define _GPY2XX_UTAPI_H_


#define MBOX_CMD_DBG				0x9
#define MBOX_CMD_UTAPI				0xA
#define MBOX_CMD_CDIAG_MODE         0x0B  // Enter CDIAG test mode
#define MBOX_CMD_CDIAG_CMD          0x0C  // Initate CDIAG test cmd

//------------------------------------------------------------------------------
//           UTAPI api id
//------------------------------------------------------------------------------
// Function prototypes
// -------------------
//
#define UTAPI_ID_XPCS_API_POLL			0x02
#define	UTAPI_ID_XPCS_API_CANCEL		0x03
#define	UTAPI_ID_XPCS_API_RESULT_REQ		0x04

/* Rx 4 point eye diagram */
#define UTAPI_ID_XPCS_4PEYE_START		0x010
#define UTAPI_ID_XPCS_4PEYE_GET_CFG		0x011
#define	UTAPI_ID_XPCS_4PEYE_RESULT_READ		0x012

/*fullsweep eye diagram*/
#define UTAPI_ID_XPCS_FULLSWEEP_START		0x018
#define UTAPI_ID_XPCS_FULLSWEEP_GET_CFG		0x019
#define	UTAPI_ID_XPCS_FULLSWEEP_RESULT_READ	0x01A

/*Scope eye diagram*/
#define UTAPI_ID_XPCS_SCOPEEYE_SWEEP_START	0x01B
#define	UTAPI_ID_XPCS_SCOPEEYE_RESULT_READ	0x01C

/*Fuction for TX automation*/
#define UTAPI_ID_INIT_EVB			0x50

#define UTAPI_ID_ACT_CHAN_TX			0x20
#define UTAPI_ID_TX_SETTINGS			0x21
#define UTAPI_ID_OFF_CHAN_TX			0x22
#define UTAPI_ID_DIS_CHAN_TX			0x23

#define UTAPI_ID_ACT_CHAN_RX			0x30
#define UTAPI_ID_RX_SETTINGS			0x31

#define UTAPI_ID_OFF_CHAN_RX			0x32
#define UTAPI_ID_DIS_CHAN_RX			0x33

#define UTAPI_ID_SET_TX_PRE_POST		0x38
#define UTAPI_ID_GET_STATUS			0x39

/*Fuction for RX automation*/
#define UTAPI_ID_TUNE_RX			0x40
#define UTAPI_ID_MEAS_EYE			0x41
#define UTAPI_ID_MEAS_BER			0x42

/* Function for Cable Diagnostic */
#define UTAPI_ID_CDIAG_START               	0x50
#define UTAPI_ID_CDIAG_RESULT_READ      	0x51
#define UTAPI_ID_CDIAG_API_POLL           	 0x52
#define UTAPI_ID_CDIAG_API_EXIT          	 0x55
#define UTAPI_ID_CDIAG_API_RESULT_NO	0x56


#endif  // __LLAPI_ID_H
