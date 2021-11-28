/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "host/ble_hs.h"
#include "host/ble_uuid.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"
#include "bleprph.h"
#include "esp_log.h"
#include "ble_ota.h"
#include "esp_ota_ops.h"
#include "esp_partition.h"

/**
 * The vendor specific security test service consists of two characteristics:
 *     o random-number-generator: generates a random 32-bit number each time
 *       it is read.  This characteristic can only be read over an encrypted
 *       connection.
 *     o static-value: a single-byte characteristic that can always be read,
 *       but can only be written over an encrypted connection.
 */

static int start_receive = 0;
static uint32_t total_size = 0;
static uint16_t counter = 0;
static uint32_t size_of_incoming_bin = 0;

/* 59462f12-9543-9999-12c8-58b459a2712d */
static const ble_uuid128_t gatt_svr_svc_ota_uuid =
    BLE_UUID128_INIT(0x2d, 0x71, 0xa2, 0x59, 0xb4, 0x58, 0xc8, 0x12,
                     0x99, 0x99, 0x43, 0x95, 0x12, 0x2f, 0x46, 0x59);

/* 5c3a659e-897e-45e1-b016-007107c96df6 */
static const ble_uuid128_t gatt_svr_chr_ota =
    BLE_UUID128_INIT(0xf6, 0x6d, 0xc9, 0x07, 0x71, 0x00, 0x16, 0xb0,
                     0xe1, 0x45, 0x7e, 0x89, 0x9e, 0x65, 0x3a, 0x5c);


static int
gatt_svr_chr_access_sec_test(uint16_t conn_handle, uint16_t attr_handle,
                             struct ble_gatt_access_ctxt *ctxt,
                             void *arg);

static const struct ble_gatt_svc_def gatt_svr_svcs[] = {
    {
        /*** Service: Security test. */
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &gatt_svr_svc_ota_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[])
        { {
                /*** Characteristic: OTA. */
                .uuid = &gatt_svr_chr_ota.u,
                .access_cb = gatt_svr_chr_access_sec_test,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_WRITE,
            }
        },
    },

    {
        0, /* No more services. */
    },
};



static int
gatt_svr_chr_access_sec_test(uint16_t conn_handle, uint16_t attr_handle,
                             struct ble_gatt_access_ctxt *ctxt,
                             void *arg)
{
    const ble_uuid_t *uuid;
    int rc;

    uuid = ctxt->chr->uuid;

    /* Determine which characteristic is being accessed by examining its
     * 128-bit UUID.
     */

    if (ble_uuid_cmp(uuid, &gatt_svr_chr_ota.u) == 0) {

        switch (ctxt->op)
        {
        case BLE_GATT_ACCESS_OP_READ_CHR:
        {
            uint8_t *gatt_svr_ota_read_buffer;
            const esp_partition_t *running = esp_ota_get_running_partition();
            esp_app_desc_t running_app_info;
            if (esp_ota_get_partition_description(running, &running_app_info) == ESP_OK) {
                gatt_svr_ota_read_buffer = (uint8_t*) running_app_info.version;
            }
            rc = os_mbuf_append(ctxt->om, gatt_svr_ota_read_buffer, 6);
            return rc == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
        }

        case BLE_GATT_ACCESS_OP_WRITE_CHR:
        {
            static uint8_t *gatt_svr_ota_write_buffer;
            int ota_buffer_size = OS_MBUF_PKTLEN(ctxt->om);
            // printf("OTA buffer size is %d\n", ota_buffer_size);
            gatt_svr_ota_write_buffer = malloc(ota_buffer_size * sizeof(uint8_t));
            rc = ble_hs_mbuf_to_flat(ctxt->om, gatt_svr_ota_write_buffer, ota_buffer_size, NULL);
            FILE *fp;
            fp = fopen(OTA_FILE_PATH, "ab" );
            int command_key = gatt_svr_ota_write_buffer[0];
            if (start_receive == 0 && command_key == BLE_OTA_START_WRITE && ota_buffer_size == 5)
            {
                start_receive = 1;
                size_of_incoming_bin = gatt_svr_ota_write_buffer[4] | (gatt_svr_ota_write_buffer[3] << 8) | (gatt_svr_ota_write_buffer[2] << 16) | (gatt_svr_ota_write_buffer[1] << 24);
                printf("Size of incoming binary file is %d\n", size_of_incoming_bin);
                free(gatt_svr_ota_write_buffer);
                gatt_svr_ota_write_buffer = NULL;
                ble_gattc_notify(conn_handle, attr_handle);
                fclose(fp);
                remove(OTA_FILE_PATH);
                return rc;
            }

            if(start_receive == 1)
            {
                if(ota_buffer_size == 1 && command_key == BLE_OTA_END_WRITE)
                {
                    start_receive = 0;
                    fclose(fp);
                    free(gatt_svr_ota_write_buffer);
                    gatt_svr_ota_write_buffer = NULL;
                    if (total_size == size_of_incoming_bin)
                    {
                        ota_task_create();
                    }
                    else
                    {
                        printf("OTA size mismatch. Aborting...\n");
                        remove(OTA_FILE_PATH);
                    }
                    return rc;
                }
                fwrite(gatt_svr_ota_write_buffer, 1, ota_buffer_size * sizeof(uint8_t), fp);
                counter = counter + 1;
                total_size = total_size + ota_buffer_size;
                printf("Counter: %d, total bytes received so far is %d\n", counter, total_size);
                ble_gattc_notify(conn_handle, attr_handle);
                free(gatt_svr_ota_write_buffer);
                gatt_svr_ota_write_buffer = NULL;
                fclose(fp);
            }
            return rc;
        }

        default:
            assert(0);
            return BLE_ATT_ERR_UNLIKELY;
        }
    }

    /* Unknown characteristic; the nimble stack should not have called this
     * function.
     */
    assert(0);
    return BLE_ATT_ERR_UNLIKELY;
}

void
gatt_svr_register_cb(struct ble_gatt_register_ctxt *ctxt, void *arg)
{
    char buf[BLE_UUID_STR_LEN];

    switch (ctxt->op) {
    case BLE_GATT_REGISTER_OP_SVC:
        MODLOG_DFLT(DEBUG, "registered service %s with handle=%d\n",
                    ble_uuid_to_str(ctxt->svc.svc_def->uuid, buf),
                    ctxt->svc.handle);
        break;

    case BLE_GATT_REGISTER_OP_CHR:
        MODLOG_DFLT(DEBUG, "registering characteristic %s with "
                    "def_handle=%d val_handle=%d\n",
                    ble_uuid_to_str(ctxt->chr.chr_def->uuid, buf),
                    ctxt->chr.def_handle,
                    ctxt->chr.val_handle);
        break;

    case BLE_GATT_REGISTER_OP_DSC:
        MODLOG_DFLT(DEBUG, "registering descriptor %s with handle=%d\n",
                    ble_uuid_to_str(ctxt->dsc.dsc_def->uuid, buf),
                    ctxt->dsc.handle);
        break;

    default:
        assert(0);
        break;
    }
}

int
gatt_svr_init(void)
{
    int rc;

    ble_svc_gap_init();
    ble_svc_gatt_init();

    rc = ble_gatts_count_cfg(gatt_svr_svcs);
    if (rc != 0) {
        return rc;
    }

    rc = ble_gatts_add_svcs(gatt_svr_svcs);
    if (rc != 0) {
        return rc;
    }

    return 0;
}
