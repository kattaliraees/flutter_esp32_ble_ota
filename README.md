## Flutter App & esp-idf sample for performing esp32 ota via BLE


1MB OTA update time, iPhone SE 2, iOS 15 ---> 2 Minutes and 15 Seconds

- One BLE Service with a Read & Writable Characteristics.
- Read will return the current running firmware version
- Write will start receiving OTA file from the App
- Write starts with a 5 bytes header packet
- 5 Bytes [StartKey, OTASizeMSB, OTASizeByte, OTASizeByte, OTASizeLSB]
- Following sending OTA bin file bytes in 512 byte writes
- At the end send the OTA End Key


### Tested on
```
boot: ESP-IDF v4.4-dev-2594-ga20df743f1 2nd stage bootloader
boot: compile time 21:09:21  
boot: chip revision: 3  
boot_comm: chip revision: 3, min. bootloader chip revision: 0  
 boot.esp32: SPI Speed      : 40MHz  
 boot.esp32: SPI Mode       : DIO  
 boot.esp32: SPI Flash Size : 8MB  
 

