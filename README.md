## Flutter App & esp-idf sample for performing ESP32 OTA via BLE


1MB OTA update time, iPhone SE 2, iOS 15 ---> 2 Minutes and 15 Seconds

#### How it works
- One BLE Service with a Read, Write & Notify GATT Characteristic is created in ESP32 firmware.
- Read of CHAR will return the current running firmware version
- OTA update starts with a 5 bytes header packet
- 5 Bytes [StartKey, OTASizeMSB, OTASizeByte, OTASizeByte, OTASizeLSB]
- Following the header bytes, OTA bin file bytes will get written to ble characteristics as batches of 514 bytes
- ESP32 firmware append this bytes to ota.bin file in SD Card
- At the end send the OTA End Key to inform firmware OTA file sending finished
- Firmware will verify the size with header bytes and total bytes received
- If file size match, it will begin OTA process at firmware side


#### Tested on
```
boot: ESP-IDF v4.4-dev-2594-ga20df743f1 2nd stage bootloader
boot: compile time 21:09:21  
boot: chip revision: 3  
boot_comm: chip revision: 3, min. bootloader chip revision: 0  
boot.esp32: SPI Speed      : 40MHz  
boot.esp32: SPI Mode       : DIO  
boot.esp32: SPI Flash Size : 8MB  
 

