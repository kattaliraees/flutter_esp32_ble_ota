/*
* ble_ota.h
*
*  Created on: September 27, 2021
*      Author: Gilroy
*/
 
//-----------------------------------------------------------------------------
#ifndef BLE_OTA_H
#define BLE_OTA_H

#define BLE_OTA_START_WRITE 0x28 // '('
#define BLE_OTA_END_WRITE 0x29 // ')'

void ota_task_create();

#endif //BLE_OTA_H