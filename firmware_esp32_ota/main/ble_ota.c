#include "ble_ota.h"
#include "esp_ota_ops.h"
#include "esp_partition.h"
#include "esp_log.h"
#include "esp_flash_partitions.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "esp_log.h"

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_ota_ops.h"
#include "esp_partition.h"


#define BUFFSIZE 512

static char ota_write_data[BUFFSIZE + 1] = { 0 };
static const char *TAG = "ble_ota";

int version_compare(const char *running_version_info, const char *new_version_info);

static void __attribute__((noreturn)) task_fatal_error(void)
{
    ESP_LOGE(TAG, "Exiting task due to fatal error...");
    (void)vTaskDelete(NULL);

    while (1) {
        ;
    }
}

void ota_begin()
{
    esp_err_t err;
    /* update handle : set by esp_ota_begin(), must be freed via esp_ota_end() */
    esp_ota_handle_t update_handle = 0 ;
    const esp_partition_t *update_partition = NULL;

    ESP_LOGI(TAG, "Starting OTA");

    const esp_partition_t *configured = esp_ota_get_boot_partition();
    const esp_partition_t *running = esp_ota_get_running_partition();

    if (configured != running) {
        ESP_LOGW(TAG, "Configured OTA boot partition at offset 0x%08x, but running from offset 0x%08x",
                 configured->address, running->address);
        ESP_LOGW(TAG, "(This can happen if either the OTA boot data or preferred boot image become corrupted somehow.)");
    }
    ESP_LOGI(TAG, "Running partition type %d subtype %d (offset 0x%08x)",
             running->type, running->subtype, running->address);

    update_partition = esp_ota_get_next_update_partition(NULL);
    assert(update_partition != NULL);
    ESP_LOGI(TAG, "Writing to partition subtype %d at offset 0x%x",
             update_partition->subtype, update_partition->address);

    esp_app_desc_t running_app_info;
    if (esp_ota_get_partition_description(running, &running_app_info) == ESP_OK) {
        ESP_LOGI(TAG, "Running firmware version: %s", running_app_info.version);
    }

    FILE *fp;
    fp = fopen(OTA_FILE_PATH, "rb");
    if (fp == NULL)
    {
        ESP_LOGE(TAG, "Failed to open OTA file for reading");
        (void)vTaskDelete(NULL);
        return;
    }
    bool image_header_was_checked = false;
    int binary_file_length = 0;
    while(1)
    {
        int bytes_read = fread(ota_write_data, 1, BUFFSIZE, fp);
        if (bytes_read > 0)
        {
            if(image_header_was_checked == false)
            {
                esp_app_desc_t new_app_info;
                // check current version with downloading
                memcpy(&new_app_info, &ota_write_data[sizeof(esp_image_header_t) + sizeof(esp_image_segment_header_t)], sizeof(esp_app_desc_t));
                ESP_LOGI(TAG, "New firmware version: %s", new_app_info.version);

                esp_app_desc_t running_app_info;
                if (esp_ota_get_partition_description(running, &running_app_info) == ESP_OK) {
                    ESP_LOGI(TAG, "Running firmware version: %s", running_app_info.version);
                }

                const esp_partition_t* last_invalid_app = esp_ota_get_last_invalid_partition();
                esp_app_desc_t invalid_app_info;
                if (esp_ota_get_partition_description(last_invalid_app, &invalid_app_info) == ESP_OK) {
                    ESP_LOGI(TAG, "Last invalid firmware version: %s", invalid_app_info.version);
                }

                // check current version with last invalid partition
                if (last_invalid_app != NULL) {
                    if (memcmp(invalid_app_info.version, new_app_info.version, sizeof(new_app_info.version)) == 0) {
                        ESP_LOGW(TAG, "New version is the same as invalid version.");
                        ESP_LOGW(TAG, "Previously, there was an attempt to launch the firmware with %s version, but it failed.", invalid_app_info.version);
                        ESP_LOGW(TAG, "The firmware has been rolled back to the previous version.");
                        (void)vTaskDelete(NULL);
                        return;
                        }
                    }

                int version_compare_results = version_compare(running_app_info.version, new_app_info.version);
                if (version_compare_results == -1)
                {
                    ESP_LOGW(TAG, "Current running version is greater than the new one. We will not continue the update.");
                    (void)vTaskDelete(NULL);
                    return;
                }

                else if (version_compare_results == 0)
                {
                    ESP_LOGW(TAG, "Current running version is the same as the new. We will not continue the update.");
                    (void)vTaskDelete(NULL);
                    return; 
                }

                image_header_was_checked = true;
                err = esp_ota_begin(update_partition, OTA_SIZE_UNKNOWN, &update_handle);
                if (err != ESP_OK) {
                    ESP_LOGE(TAG, "esp_ota_begin failed (%s)", esp_err_to_name(err));
                    esp_ota_abort(update_handle);
                    task_fatal_error();
                }
                ESP_LOGI(TAG, "esp_ota_begin succeeded");
            }

            err = esp_ota_write( update_handle, (const void *)ota_write_data, bytes_read);
            if (err != ESP_OK) {
                esp_ota_abort(update_handle);
                ESP_LOGE(TAG, "Write failed\n");
                task_fatal_error();
            }
            binary_file_length += bytes_read;
            ESP_LOGD(TAG, "Written image length %d", binary_file_length);
        }
        else if (bytes_read < 0)
        {
            ESP_LOGE(TAG, "Reading negative. Error");
        }
        else if (bytes_read == 0)
        {
            ESP_LOGI(TAG, "Reading completed");
            break;
        }
    }
    ESP_LOGI(TAG, "Total Write binary data length: %d", binary_file_length);
    
    err = esp_ota_end(update_handle);
    if (err != ESP_OK) {
        if (err == ESP_ERR_OTA_VALIDATE_FAILED) {
                ESP_LOGE(TAG, "Image validation failed, image is corrupted");
        } 
        else {
            ESP_LOGE(TAG, "esp_ota_end failed (%s)!", esp_err_to_name(err));
        }
        task_fatal_error();
    }

    err = esp_ota_set_boot_partition(update_partition);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "esp_ota_set_boot_partition failed (%s)!", esp_err_to_name(err));
        task_fatal_error();
    }
    fclose(fp);
    remove(OTA_FILE_PATH);
    ESP_LOGI(TAG, "Prepare to restart system!");
    esp_restart();
    return ;
}

void ota_task_create()
{
    xTaskCreate(&ota_begin, "ota_begin", 8192, NULL, 5, NULL);
}

int version_compare(const char *running_version_info, const char *new_version_info)
{
    unsigned running_version_major = 0, running_version_minor = 0, running_version_build = 0;
    unsigned new_version_major = 0, new_version_minor = 0, new_version_build = 0;

    sscanf(running_version_info, "%u.%u.%u", &running_version_major, &running_version_minor, &running_version_build);
    sscanf(new_version_info, "%u.%u.%u", &new_version_major, &new_version_minor, &new_version_build);

    if(new_version_major > running_version_major)
        return 1;

    else if (new_version_major < running_version_major)
        return -1;

    else if (new_version_minor > running_version_minor)
        return 1;

    else if (new_version_minor < running_version_minor)
        return -1;

    else if (new_version_build > running_version_build)
        return 1;

    else if (new_version_build < running_version_build)
        return -1;

    else
        return 0;
}