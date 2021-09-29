import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter/services.dart' show rootBundle;

class BLEManager extends ChangeNotifier {
  final _otaServiceUUID = Uuid.parse("9A1B08AE-F898-08FF-329E-2E9AAF91F734");
  final _otaCharacteristicsUUID =
      Uuid.parse("2F6A8A4C-7DC7-4230-8668-5160AAA71DAA");

  int connectionState = 0;
  final flutterReactiveBle = FlutterReactiveBle();
  DiscoveredDevice? connectedBLEDevice;
  String? foundDevciceID;

  bool _isScanning = false;
  int notifyCount = 0;
  bool isOTARunning = false;

  Future<Uint8List> loadAsset() async {
    final binBlob = await rootBundle.load('assets/sajdah_esp.bin');
    Uint8List bytes = binBlob.buffer.asUint8List();

    return bytes;
  }

  void writeBytesToOTACharecteristicsWithNotify() async {
    if (connectionState == 1 && foundDevciceID!.isNotEmpty) {
      if (isOTARunning) {
        return;
      }

      isOTARunning = true;
      final otaData = await loadAsset();
      final startKey = '(';
      final endKey = ')';
      final safetyDelay = 100;
      int start = 0;
      final chunkSize = 514;
      int totalRead = chunkSize;
      bool isLastChunkSent = false;

      final characteristic = QualifiedCharacteristic(
          serviceId: _otaServiceUUID,
          characteristicId: _otaCharacteristicsUUID,
          deviceId: foundDevciceID!);
      flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic,
          value: startKey.codeUnits);
      flutterReactiveBle.subscribeToCharacteristic(characteristic).listen(
          (data) async {
        if (isLastChunkSent) {
          //await Future.delayed(Duration(milliseconds: safetyDelay));
          flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic,
              value: endKey.codeUnits);
          print('END OF OTA WRITE');
          isOTARunning = false;
        }
        notifyCount = notifyCount + 1;

        if ((totalRead + chunkSize) > otaData.length) {
          final lastChunk = otaData.getRange(start, otaData.length).toList();
          await Future.delayed(Duration(milliseconds: safetyDelay));
          isLastChunkSent = true;
          flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic,
              value: lastChunk);
          print(
              '$notifyCount WRITING OTA BYTES FROM $start to ${otaData.length} to GATT SERVER');
        } else {
          //await Future.delayed(Duration(milliseconds: safetyDelay));
          final chunk = otaData.getRange(start, totalRead).toList();
          print(
              '$notifyCount WRITING OTA BYTES FROM $start to $totalRead to GATT SERVER');
          start = totalRead;
          totalRead = totalRead + chunkSize;
          flutterReactiveBle.writeCharacteristicWithoutResponse(characteristic,
              value: chunk);
        }

        // code to handle incoming data
      }, onError: (dynamic error) {
        // code to handle errors
      });
    }
  }

  void scanAndConnect() {
    if (_isScanning) {
      return;
    }
    _isScanning = true;
    flutterReactiveBle.scanForDevices(
        withServices: [_otaServiceUUID],
        scanMode: ScanMode.lowLatency).listen((device) {
      foundDevciceID = device.id;
      connectionState = 1;
      _isScanning = false;
      //code for handling results

      flutterReactiveBle
          .connectToDevice(
        id: foundDevciceID!,
        servicesWithCharacteristicsToDiscover: {
          Uuid.parse(foundDevciceID!): [_otaCharacteristicsUUID]
        },
        connectionTimeout: const Duration(seconds: 2),
      )
          .listen((connectionState) {
        if (connectionState.connectionState ==
            DeviceConnectionState.connected) {
          this.connectionState = 1;
        }
        // Handle connection state updates
        print(connectionState);
      }, onError: (Object error) {
        // Handle a possible error
      });
    }, onError: (e) {
      print('Scanning failed');
    });
  }
}
