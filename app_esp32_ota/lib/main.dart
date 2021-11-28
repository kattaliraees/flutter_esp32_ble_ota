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
      home: MyHomePage(title: 'ESP32 OTA'),
    );
  }
}

class MyHomePage extends StatelessWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  final ble = BLEProvider();

  @override
  Widget build(BuildContext context) {
    ble.scanAndConnect(() {});
    return Scaffold(
      body: Center(
        child: MaterialButton(
          child: Text('Start OTA'),
          color: Colors.blue,
          onPressed: () {
            ble.writeBytesToOTACharecteristicsWithNotify(() async {
              await Future.delayed(
                  Duration(seconds: 2)); //Wait for ESP32 to restart
              ble.scanAndConnect(() {});
              final updatedFirmwareVersion = ble.getFirmwareVersion();
              print(updatedFirmwareVersion);
            });
          },
        ),
      ),
    );
  }
}
