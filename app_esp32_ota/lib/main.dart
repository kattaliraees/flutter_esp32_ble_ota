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

class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ble = BLEProvider();
    bool connected = false;
    ble.scanAndConnect(() {
      connected = true;
    });
    return Scaffold(
      body: Center(
        child: MaterialButton(
          child: Text('Start OTA'),
          color: Colors.blue,
          onPressed: () {
            if (connected) {
              ble.writeBytesToOTACharecteristicsWithNotify(() async {
                await Future.delayed(
                    Duration(seconds: 2)); //Wait for ESP32 to restart
                ble.scanAndConnect(() {
                  connected = true;
                  final updatedFirmwareVersion = ble.getFirmwareVersion();
                  print(updatedFirmwareVersion);
                });
                connected = false;
              });
            }
          },
        ),
      ),
    );
  }
}
