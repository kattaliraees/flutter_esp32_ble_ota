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
    return ChangeNotifierProvider(
        create: (_) => BLEManager(),
        child: MaterialApp(
          title: 'ESP32 BLE OTA Demo',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          home: MyHomePage(title: 'ESP32 OTA'),
        ));
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  BLEManager? _ble;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _ble = Provider.of<BLEManager>(context, listen: true);
    //print(_ble!.connectionState);
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [buttonList()],
          ),
        ));
  }

  Widget buttonList() {
    if (_ble!.connectionState == 1) {
      return TextButton(
          onPressed: () {
            _ble!.writeBytesToOTACharecteristicsWithNotify();
            //_ble!.writeBytesToOTACharecteristics();
            //_ble!.test();
          },
          child: const Text('Start OTA'));
    } else {
      return TextButton(
          onPressed: () {
            _ble!.scanAndConnect();
          },
          child: const Text('Scan and Connect'));
    }
  }
}
