### Flutter App & esp-idf sample for performing esp32 ota via BLE


1MB OTA update time, iPhone SE 2, iOS 15 ---> 2 Minutes and 15 Seconds

- One BLE Service with a Read & Writable Characteristics.
- Read will return the current running firmware version
- Write will start receiving OTA file from the App
- Write starts with a 5 bytes header packet
- 5 Bytes [StartKey, OTASizeMSB, OTASizeByte, OTASizeByte, OTASizeLSB]
- Following sending OTA bin file bytes in 512 byte writes
- End Key

