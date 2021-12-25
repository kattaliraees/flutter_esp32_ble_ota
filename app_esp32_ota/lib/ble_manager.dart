import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter/services.dart' show rootBundle;

typedef BLEConnect = void Function(bool);

enum BLEConnectionStatus { Unknown, Connecting, Connected, FailedToConnect }

class BLEProvider extends ChangeNotifier {
  static const BLE_SERVICE_UUID = "6DD61F0E-9AEC-4C79-A62E-98910433CCC5";
  static const BLE_CHAR_OTA_UUID = "6366C65E-37F4-4650-9AEF-5AEF56F67EA1";
  static const GATT_SVR_SVC_ALERT_UUID = '1811';

  //extends ChangeNotifier {
  final flutterReactiveBle = FlutterReactiveBle();
  BLEConnectionStatus connectionStatus = BLEConnectionStatus.Unknown;
  bool stopNotify = false;
  String? foundDeviceID;

  //OTA
  double otaProgress = 0;
  bool isOTARunning = false;

  void scanAndConnect(Function cb, [String? deviceID]) {
    StreamSubscription<BleStatus>? bleStatusStreamSubscription;
    bleStatusStreamSubscription =
        flutterReactiveBle.statusStream.listen((bleStatus) async {
      if (bleStatus == BleStatus.ready) {
        await bleStatusStreamSubscription!.cancel();
        connectionStatus = BLEConnectionStatus.Connecting;
        Stream<DiscoveredDevice> stream;
        stream = flutterReactiveBle.scanForDevices(
            withServices: [Uuid.parse(GATT_SVR_SVC_ALERT_UUID)],
            scanMode: ScanMode.lowLatency);

        StreamSubscription<DiscoveredDevice>? deviceStreamSubscription;
        deviceStreamSubscription = stream.listen((d) async {
          if (deviceID != null) {
            if (d.id == deviceID) {
              //Cancel searching if only the paired device is found
              await deviceStreamSubscription!.cancel();
              foundDeviceID = deviceID;
            }
          } else {
            //Cancel searching once a new nearby SAJDAH device is founb
            await deviceStreamSubscription!.cancel();
          }

          print(d.id.toLowerCase());

          flutterReactiveBle
              .connectToDevice(
            id: d.id,
            servicesWithCharacteristicsToDiscover: {
              Uuid.parse(BLE_SERVICE_UUID): [Uuid.parse(BLE_CHAR_OTA_UUID)]
            },
            connectionTimeout: const Duration(seconds: 2),
          )
              .listen((c) async {
            if (c.connectionState == DeviceConnectionState.connected) {
              connectionStatus = BLEConnectionStatus.Connected;

              final characteristic = QualifiedCharacteristic(
                  serviceId: Uuid.parse(BLE_SERVICE_UUID),
                  characteristicId: Uuid.parse(BLE_CHAR_OTA_UUID),
                  deviceId: d.id);
              foundDeviceID = d.id;
              final response =
                  await flutterReactiveBle.readCharacteristic(characteristic);
              final currentFirmwareVersion = utf8.decode(response);
              print("currentFirmwareVersion - $currentFirmwareVersion");
              if (response.length > 0) {
                if (!stopNotify) cb();
              }
            } else {
              connectionStatus = BLEConnectionStatus.FailedToConnect;
              if (!stopNotify) cb();
            }

            // Handle connection state updates
          }, onError: (error) {
            connectionStatus = BLEConnectionStatus.FailedToConnect;
            print(error);
          });
        }, onError: (err) {
          print(err);
        });
      }
    });
  }

  Future<String> getFirmwareVersion() async {
    if (connectionStatus == BLEConnectionStatus.Connected) {
      final characteristic = QualifiedCharacteristic(
          serviceId: Uuid.parse(BLE_SERVICE_UUID),
          characteristicId: Uuid.parse(BLE_CHAR_OTA_UUID),
          deviceId: foundDeviceID!);
      final response =
          await flutterReactiveBle.readCharacteristic(characteristic);

      return utf8.decode(response);
    }

    return '';
  }

  void writeBytesToOTACharecteristicsWithNotify(Function cb) async {
    if (isOTARunning) {
      return;
    }

    if (connectionStatus == BLEConnectionStatus.Connected) {
      isOTARunning = true;
      final otaData = await _getFirmwareBinBytes();
      double totalSizeOfBin = otaData.length.toDouble();

      final characteristic = QualifiedCharacteristic(
          serviceId: Uuid.parse(BLE_SERVICE_UUID),
          characteristicId: Uuid.parse(BLE_CHAR_OTA_UUID),
          deviceId: foundDeviceID!);
      
      if (Platform.isAndroid)
        await flutterReactiveBle.requestConnectionPriority(
            deviceId: foundDeviceID,
            priority: ConnectionPriority.highPerformance);

      final mtu = await flutterReactiveBle.requestMtu(
          deviceId: foundDeviceID, mtu: 517);
      print('Updated MTU - $mtu');
      

      print(DateTime.now().toString()); //OTA Start time
      final otaDataSize = otaData.length;
      List<int> sizeBytes = [
        0x28,
        (otaDataSize & 0xFF000000) >> 24,
        (otaDataSize & 0xFF0000) >> 16,
        (otaDataSize & 0x00FF00) >> 8,
        (otaDataSize & 0x0000FF)
      ];
      final endKey = ')';
      int start = 0;
      final chunkSize = 514;
      int totalRead = chunkSize;
      bool isLastChunkSent = false;

      StreamSubscription<List<int>>? bleStatusStreamSubscription;
      bleStatusStreamSubscription = flutterReactiveBle
          .subscribeToCharacteristic(characteristic)
          .listen((event) async {
        otaProgress = totalRead.toDouble() / totalSizeOfBin;
        notifyListeners();
        if (isLastChunkSent) {
          await bleStatusStreamSubscription!.cancel();
          await flutterReactiveBle.writeCharacteristicWithResponse(
              characteristic,
              value: endKey.codeUnits);
          print('END OF OTA WRITE');
          print(DateTime.now().toString()); //OTA End time
          isOTARunning = false;
          otaProgress = 0;
          notifyListeners();
          cb();
          return;
        }
        if (totalRead > otaData.length) {
          final lastChunk = otaData.getRange(start, otaData.length).toList();
          isLastChunkSent = true;
          await flutterReactiveBle.writeCharacteristicWithResponse(
              characteristic,
              value: lastChunk);
          print('OTA Progress - Sent last byte');
        } else {
          //await Future.delayed(Duration(milliseconds: safetyDelay));
          final chunk = otaData.getRange(start, totalRead).toList();
          print('OTA Progress - $otaProgress');
          start = totalRead;
          totalRead = totalRead + chunkSize;
          await flutterReactiveBle
              .writeCharacteristicWithResponse(characteristic, value: chunk);
        }
      });
      await flutterReactiveBle.writeCharacteristicWithResponse(characteristic,
          value: sizeBytes);
    }
  }

  Future<Uint8List> _getFirmwareBinBytes() async {
    final binBlob = await rootBundle.load('assets/ota.bin');
    Uint8List bytes = binBlob.buffer.asUint8List();

    return bytes;
  }
}
