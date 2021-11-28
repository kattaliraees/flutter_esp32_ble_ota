import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ble_manager.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 BLE OTA Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

//Make stateful widget for proper implementation and use otaprogress notifier value for progress.
//This is a very simple  & quick implementtion.
class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ble = BLEProvider();
    bool otaRunning = false;

    return Scaffold(
      body: Center(
        child: MaterialButton(
          child: Text('Start OTA'),
          color: Colors.blue,
          onPressed: () {
            if (otaRunning) {
              return;
            }
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
          },
        ),
      ),
    );
  }
}
