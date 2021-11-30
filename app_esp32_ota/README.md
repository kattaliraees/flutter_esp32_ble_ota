## ESP32 BLE OTA Flutter App

Flutter App for Sending ESP32 bin file over BLE

```dart
ble.scanAndConnect(() {
  if (ble.connectionStatus == BLEConnectionStatus.Connected) {
    otaRunning = true;
    ble.writeBytesToOTACharecteristicsWithNotify(() async {
      await Future.delayed(
          Duration(seconds: 2)); //Wait for ESP32 to restart
      ble.scanAndConnect(() {
        if (ble.connectionStatus == BLEConnectionStatus.Connected) {
          otaRunning = false;
          ble.stopNotify = true;
          final updatedFirmwareVersion = ble.getFirmwareVersion();
          print(updatedFirmwareVersion);
        }
      });
    });
  }
});
