import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database_helper.dart';
import 'package:bench_cstr_ui/data_visualization_screen.dart';
import 'dart:async';
import 'package:bench_cstr_ui/data_display_screen.dart';
//import 'package:fl_chart/fl_chart.dart';

void main() {
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(CSTRControllerApp());
}

class CSTRControllerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CSTR Controller',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  bool isMixerOn = false;
  bool isFeedOn = false;
  double pHValue = 7.0;
  double orpValue = 120.4;
  double temperatureValue = 86.3;
  double feedRateValue = 14.2;
  double ch4Value = 1.03;
  double mixerSpeedValue = 138.0;

  final String broker = 'localhost';
  final int port = 1883;
  final String topic = 'cstr/controller';

  late MqttServerClient client;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _setupMqttClient();
  }

  Future<void> _setupMqttClient() async {
    client = MqttServerClient(broker, '');
    client.port = port;
    client.logging(on: true);
    client.onConnected = _onConnected;
    client.onDisconnected = _onDisconnected;
    client.onSubscribed = _onSubscribed;
    client.onUnsubscribed = _onUnsubscribed;
    client.onSubscribeFail = _onSubscribeFail;
    client.pongCallback = _pong;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('CSTRControllerApp')
        .withWillTopic('willtopic')
        .withWillMessage('Will message')
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMessage;

    try {
      await client.connect();
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final String payload = 
          MqttPublishPayload.bytesToStringAsString(message.payload.message);
      _handleIncomingMessage(payload);
    });

    client.subscribe(topic, MqttQos.atLeastOnce);
  }

  void _onConnected() {
    print('Connected');
  }

  void _onDisconnected() {
    print('Disconnected');
  }

  void _onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  void _onUnsubscribed(String? topic) {
    print('Unsubscribed from $topic');
  }

  void _onSubscribeFail(String topic) {
    print('Failed to subscribe $topic');
  }

  void _pong() {
    print('Ping response client callback invoked');
  }

  void _handleIncomingMessage(String payload) {
    print('Received message: $payload');

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 300), () {
      try {
        final Map<String, dynamic> data = jsonDecode(payload);

        setState(() {
          pHValue = data['pH'];
          orpValue = data['ORP'];
          temperatureValue = data['temperature'];
          feedRateValue = data['feed_rate'];
          ch4Value = data['CH4'];
          mixerSpeedValue = data['mixer_speed'];
          DatabaseHelper().insertData('pH', pHValue);
          DatabaseHelper().insertData('ORP', orpValue);
          DatabaseHelper().insertData('temperature', temperatureValue);
          DatabaseHelper().insertData('feed_rate', feedRateValue);
          DatabaseHelper().insertData('CH4', ch4Value);
          DatabaseHelper().insertData('mixer_speed', mixerSpeedValue);
        });
      } catch (e) {
        print('Error parsing JSON: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('CSTR Controller'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.power_settings_new),
            onPressed: _showPowerDialog,
          ),
          Icon(Icons.wifi, color: Colors.blue, size: 30),
          SizedBox(width: 10),
          Icon(Icons.bluetooth, color: Colors.blue, size: 30),
          SizedBox(width: 10),
          Icon(Icons.cloud, color: Colors.white, size: 30),
          SizedBox(width: 10),
        ],
      ),
      drawer: MainMenuDrawer(),
      body: Column(
        children: [
          Image.asset('assets/bgs_logo_nobkg.jpg', height: 100),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 4,
                children: [
                  DataTile(
                    label: 'pH',
                    value: pHValue.toStringAsFixed(2),
                    unit: '',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsScreen(
                          title: 'pH Settings',
                          parameters: {
                            'Setpoint': '7.20',
                            'High Limit': '8.00',
                            'Low Limit': '6.50',
                          },
                          inputRange: {
                            'Setpoint': [0.00, 14.00],
                            'High Limit': [0.00, 14.00],
                            'Low Limit': [0.00, 14.00],
                          },
                          unitPreference: null,
                          showCalibrate: true,
                        )),
                      );
                    },
                  ),
                  DataTile(
                    label: 'ORP',
                    value: orpValue.toStringAsFixed(1),
                    unit: 'mV',
                    color: Colors.grey,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsScreen(
                          title: 'ORP Settings',
                          parameters: {
                            'Setpoint': '120.4',
                            'High Limit': '150.0',
                            'Low Limit': '90.0',
                          },
                          inputRange: {
                            'Setpoint': [-500.0, 500.0],
                            'High Limit': [-500.0, 500.0],
                            'Low Limit': [-500.0, 500.0],
                          },
                          unitPreference: null,
                          showCalibrate: true,
                        )),
                      );
                    },
                  ),
                  DataTile(
                    label: 'Temperature',
                    value: temperatureValue.toStringAsFixed(1),
                    unit: '°F',
                    color: Colors.yellow,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsScreen(
                          title: 'Temperature Settings',
                          parameters: {
                            'Setpoint': '86.3',
                            'High Limit': '90.0',
                            'Low Limit': '80.0',
                          },
                          inputRange: {
                            'Setpoint': [0.0, 100.0],
                            'High Limit': [0.0, 100.0],
                            'Low Limit': [0.0, 100.0],
                          },
                          unitPreference: UnitPreference(
                            label: 'Temperature Unit',
                            options: ['Celsius', 'Fahrenheit'],
                            selectedOption: 'Fahrenheit',
                          ),
                          showCalibrate: true,
                        )),
                      );
                    },
                  ),
                  DataTile(
                    label: 'Feed',
                    value: feedRateValue.toStringAsFixed(1),
                    unit: 'mL/min',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsScreen(
                          title: 'Feed Settings',
                          parameters: {
                            'Setpoint': '14.2',
                            'High Limit': '20.0',
                            'Low Limit': '10.0',
                          },
                          inputRange: {
                            'Setpoint': [0.0, 50.0],
                            'High Limit': [0.0, 50.0],
                            'Low Limit': [0.0, 50.0],
                          },
                          unitPreference: UnitPreference(
                            label: 'Feed Unit',
                            options: ['mL/min', 'mL/hr', 'mL/d', 'L/h', 'L/d', 'm3/h', 'm3/d', 'gal/h', 'gal/d', 'ft3/min'],
                            selectedOption: 'mL/min',
                          ),
                          showCalibrate: true,
                        )),
                      );
                    },
                  ),
                  DataTile(
                    label: 'CH4',
                    value: ch4Value.toStringAsFixed(2),
                    unit: 'mL/min',
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsScreen(
                          title: 'CH4 Settings',
                          parameters: {
                            'Setpoint': '1.03',
                            'High Limit': '1.50',
                            'Low Limit': '0.50',
                          },
                          inputRange: {
                            'Setpoint': [0.0, 10.0],
                            'High Limit': [0.0, 10.0],
                            'Low Limit': [0.0, 10.0],
                          },
                          unitPreference: UnitPreference(
                            label: 'CH4 Unit',
                            options: ['mL/min', 'mL/hr', 'mL/d', 'L/h', 'L/d', 'ft3/min', 'ft3/hr', 'ft3/d'],
                            selectedOption: 'mL/min',
                          ),
                          showCalibrate: false,
                        )),
                      );
                    },
                  ),
                  DataTile(
                    label: 'Mixer Speed',
                    value: mixerSpeedValue.toStringAsFixed(0),
                    unit: 'rpm',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SettingsScreen(
                          title: 'Mixer Speed Settings',
                          parameters: {
                            'Setpoint': '138.0',
                            'High Limit': '200.0',
                            'Low Limit': '100.0',
                          },
                          inputRange: {
                            'Setpoint': [0.0, 300.0],
                            'High Limit': [0.0, 300.0],
                            'Low Limit': [0.0, 300.0],
                          },
                          unitPreference: null,
                          showCalibrate: false,
                        )),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPowerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Power Control'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text('Mixer'),
                    value: isMixerOn,
                    onChanged: (bool value) {
                      setState(() {
                        isMixerOn = value;
                      });
                      this.setState(() {
                        isMixerOn = value;
                      });
                      _publishMessage('mixer:${value ? 'on' : 'off'}');
                    },
                  ),
                  SwitchListTile(
                    title: Text('Feed'),
                    value: isFeedOn,
                    onChanged: (bool value) {
                      setState(() {
                        isFeedOn = value;
                      });
                      this.setState(() {
                        isFeedOn = value;
                      });
                      _publishMessage('feed:${value ? 'on' : 'off'}');
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Close'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _publishMessage(String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.exactlyOnce, builder.payload!);
  }
}

class DataTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final VoidCallback onTap;

  DataTile({required this.label, required this.value, required this.unit, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: Text(
                label,
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
            Center(
              child: Text(
                value,
                style: TextStyle(fontSize: 28, color: Colors.white),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Text(
                unit,
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MainMenuDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Text(
              'Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('App Settings'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AppSettingsScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.history),
            title: Text('Calibration Records'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => CalibrationRecordsScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.show_chart),
            title: Text('Visualize Data'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DataVisualizationScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.show_chart),
            title: Text('Datalog'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DataDisplayScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.build),
            title: Text('Project Settings'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ProjectSettingsHomeScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
//////////////////////////Parameter Settings////////////////////////////////
class SettingsScreen extends StatelessWidget {
  final String title;
  final Map<String, String> parameters;
  final Map<String, List<double>>? inputRange;
  final UnitPreference? unitPreference;
  final bool showCalibrate;

  SettingsScreen({
    required this.title,
    required this.parameters,
    this.inputRange,
    this.unitPreference,
    required this.showCalibrate,
  });

  void _showCalibrateDialog(BuildContext context, String type) {
    showDialog(
      context: context,
      builder: (context) {
        if (type == 'pH') {
          return _phCalibrateDialog(context);
        } else if (type == 'ORP') {
          return _orpCalibrateDialog(context);
        } else if (type == 'Temperature') {
          return _temperatureCalibrateDialog(context);
        } else if (type == 'Feed') {
          return _feedCalibrateDialog(context);
        }
        return SizedBox.shrink();
      },
    );
  }

  AlertDialog _phCalibrateDialog(BuildContext context) {
    return AlertDialog(
      title: Text('Calibrate pH'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () {
              _showInputValueDialog(context, 'pH 4');
            },
            child: Text('pH 4'),
          ),
          ElevatedButton(
            onPressed: () {
              _showInputValueDialog(context, 'pH 7');
            },
            child: Text('pH 7'),
          ),
          ElevatedButton(
            onPressed: () {
              _showInputValueDialog(context, 'pH 10');
            },
            child: Text('pH 10'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
      ],
    );
  }

  AlertDialog _orpCalibrateDialog(BuildContext context) {
    return AlertDialog(
      title: Text('Calibrate ORP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Enter concentration (mV)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showInputValueDialog(context, 'ORP Reading');
          },
          child: Text('Continue'),
        ),
      ],
    );
  }

  AlertDialog _temperatureCalibrateDialog(BuildContext context) {
    return AlertDialog(
      title: Text('Calibrate Temperature'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Temperature 1'),
          ),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Temperature 2'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Continue'),
        ),
      ],
    );
  }

  AlertDialog _feedCalibrateDialog(BuildContext context) {
    return AlertDialog(
      title: Text('Calibrate Feed'),
      content: TextField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: 'Enter calibration volume (mL)'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showFeedInputValueDialog(context, 'Measured volume (mL)');
          },
          child: Text('Continue'),
        ),
      ],
    );
  }

  void _showFeedInputValueDialog(BuildContext context, String title) {
    String selectedUnit = 'seconds';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'Enter measured volume (mL)'),
              ),
              TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'Enter time passed'),
              ),
              DropdownButton<String>(
                value: selectedUnit,
                items: ['seconds', 'minutes'].map((String unit) {
                  return DropdownMenuItem<String>(
                    value: unit,
                    child: Text(unit),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    selectedUnit = newValue;
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  void _showInputValueDialog(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: 'Enter value'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          Icon(Icons.wifi, color: Colors.blue),
          Icon(Icons.bluetooth, color: Colors.blue),
          Icon(Icons.cloud, color: Colors.white),
          Builder(
            builder: (context) {
              return IconButton(
                icon: Icon(Icons.menu, size: 30),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.home, size: 30),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      drawer: MainMenuDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 4,
                children: [
                  ...parameters.keys.map((key) {
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            String newValue = parameters[key]!;
                            return AlertDialog(
                              title: Text('Change $key'),
                              content: TextField(
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                onChanged: (value) {
                                  newValue = value;
                                },
                                decoration: InputDecoration(hintText: 'Enter new value'),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Handle the new value here (e.g., update state, send to server)
                                    if (inputRange != null && inputRange!.containsKey(key)) {
                                      double? doubleValue = double.tryParse(newValue);
                                      if (doubleValue != null && doubleValue >= inputRange![key]![0] && doubleValue <= inputRange![key]![1]) {
                                        // Valid range, proceed
                                        parameters[key] = newValue;
                                        Navigator.of(context).pop();
                                      } else {
                                        // Invalid range, show error
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text('Invalid Input'),
                                            content: Text('Value must be between ${inputRange![key]![0]} and ${inputRange![key]![1]}'),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                },
                                                child: Text('OK'),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    } else {
                                      // No range specified, just update
                                      parameters[key] = newValue;
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: Text('Continue'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Text(
                                key,
                                style: TextStyle(fontSize: 20, color: Colors.white),
                              ),
                            ),
                            Center(
                              child: Text(
                                parameters[key]!,
                                style: TextStyle(fontSize: 28, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  if (unitPreference != null) unitPreference!,
                ],
              ),
            ),
            if (showCalibrate)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 50),
                  ),
                  onPressed: () {
                    _showCalibrateDialog(context, title.split(' ')[0]);
                  },
                  child: Text('Calibrate'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UnitPreference extends StatelessWidget {
  final String label;
  final List<String> options;
  final String selectedOption;

  UnitPreference({required this.label, required this.options, required this.selectedOption});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 20, color: Colors.white),
            ),
            DropdownButton<String>(
              value: selectedOption,
              dropdownColor: Colors.blue,
              icon: Icon(Icons.arrow_downward, color: Colors.white),
              iconSize: 24,
              elevation: 16,
              style: TextStyle(color: Colors.white),
              underline: Container(
                height: 2,
                color: Colors.white,
              ),
              onChanged: (String? newValue) {
                // Handle the new value here (e.g., update state, send to server)
              },
              items: options.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
//////////////////////////////APP Settings////////////////////////////////
class AppSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('App Settings'),
        centerTitle: true,
        actions: [
          Icon(Icons.wifi, color: Colors.blue),
          Icon(Icons.bluetooth, color: Colors.blue),
          Icon(Icons.cloud, color: Colors.white),
          Builder(
            builder: (context) {
              return IconButton(
                icon: Icon(Icons.menu, size: 30),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.home, size: 30),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      drawer: MainMenuDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SettingsButton(
              label: 'Connect to WiFi',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => WifiSettingsScreen()),
                );
              },
            ),
            SettingsButton(
              label: 'Connect to Bluetooth',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => BluetoothSettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  SettingsButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 50),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
///////////////////////////////WiFi Settings//////////////////////////////////////
class WifiSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Connect to WiFi'),
        centerTitle: true,
        actions: [
          Icon(Icons.wifi, color: Colors.blue),
          Icon(Icons.bluetooth, color: Colors.blue),
          Icon(Icons.cloud, color: Colors.white),
          Builder(
            builder: (context) {
              return IconButton(
                icon: Icon(Icons.menu, size: 30),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.home, size: 30),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      drawer: MainMenuDrawer(),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text('Network $index', style: TextStyle(color: Colors.white)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  String password = '';
                  return AlertDialog(
                    title: Text('Enter Password for Network $index'),
                    content: TextField(
                      obscureText: true,
                      onChanged: (value) {
                        password = value;
                      },
                      decoration: InputDecoration(hintText: 'Password'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Continue'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
//////////////////////////////Bluetooth Settings//////////////////////////////////
class BluetoothSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Connect to Bluetooth'),
        centerTitle: true,
        actions: [
          Icon(Icons.wifi, color: Colors.blue),
          Icon(Icons.bluetooth, color: Colors.blue),
          Icon(Icons.cloud, color: Colors.white),
          Builder(
            builder: (context) {
              return IconButton(
                icon: Icon(Icons.menu, size: 30),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.home, size: 30),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      drawer: MainMenuDrawer(),
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text('Device $index', style: TextStyle(color: Colors.white)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  String password = '';
                  return AlertDialog(
                    title: Text('Enter Password for Device $index'),
                    content: TextField(
                      obscureText: true,
                      onChanged: (value) {
                        password = value;
                      },
                      decoration: InputDecoration(hintText: 'Password'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Continue'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
///////////////////////////////Calibration Records/////////////////////////////////
class CalibrationRecordsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Calibration Records'),
        centerTitle: true,
        actions: [
          Icon(Icons.wifi, color: Colors.blue),
          Icon(Icons.bluetooth, color: Colors.blue),
          Icon(Icons.cloud, color: Colors.white),
          Builder(
            builder: (context) {
              return IconButton(
                icon: Icon(Icons.menu, size: 30),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.home, size: 30),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      drawer: MainMenuDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            MenuButton(
              label: 'pH Calibrations',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CalibrationDataScreen(
                    title: 'pH Calibration Records',
                    columns: ['Cal. Date', 'Cal. Time', 'pH 4 mV', 'pH 7 mV', '% Slope 1', 'pH 10 mV', '% Slope 2'],
                    data: [],
                  )),
                );
              },
            ),
            MenuButton(
              label: 'ORP Calibrations',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CalibrationDataScreen(
                    title: 'ORP Calibration Records',
                    columns: ['Cal. Date', 'Cal. Time', 'Cal. Sol. mV', 'mV Read', 'Offset'],
                    data: [],
                  )),
                );
              },
            ),
            MenuButton(
              label: 'Temperature Calibrations',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CalibrationDataScreen(
                    title: 'Temperature Calibration Records',
                    columns: ['Cal. Date', 'Cal. Time', 'Temp. Reading', 'Reference'],
                    data: [],
                  )),
                );
              },
            ),
            MenuButton(
              label: 'Feed Calibrations',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CalibrationDataScreen(
                    title: 'Feed Calibration Records',
                    columns: ['Cal. Date', 'Cal. Time', 'Cal. Volume', 'Measured volume', 'Pump Speed'],
                    data: [],
                  )),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
////////////////////////////Calibration Data//////////////////////////////////
class CalibrationDataScreen extends StatelessWidget {
  final String title;
  final List<String> columns;
  final List<List<String>> data;

  CalibrationDataScreen({required this.title, required this.columns, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: [
          Icon(Icons.wifi, color: Colors.blue),
          Icon(Icons.bluetooth, color: Colors.blue),
          Icon(Icons.cloud, color: Colors.white),
          Builder(
            builder: (context) {
              return IconButton(
                icon: Icon(Icons.menu, size: 30),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.home, size: 30),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => MainScreen()),
              (Route<dynamic> route) => false,
            );
          },
        ),
      ),
      drawer: MainMenuDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () {
                // Implement filtering logic here
              },
              child: Text('Filter'),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: columns.map((column) => DataColumn(label: Text(column, style: TextStyle(color: Colors.white)))).toList(),
                  rows: data.map((row) {
                    return DataRow(
                      cells: row.map((cell) => DataCell(Text(cell, style: TextStyle(color: Colors.white)))).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProjectSettingsHomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Project Settings'),
        centerTitle: true,
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NewProjectScreen()),
            );
          },
          child: Text('New Project'),
        ),
      ),
    );
  }
}

class NewProjectScreen extends StatefulWidget {
  @override
  NewProjectScreenState createState() => NewProjectScreenState();
}

class NewProjectScreenState extends State<NewProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  String projectName = '';
  int cstrUnits = 1;
  String treatmentType = '';
  int dataloggingFrequency = 5; // default value
  List<String> parametersToLog = [];
  final List<String> availableParameters = ['pH', 'ORP', 'Temperature', 'Biogas', 'Mixing', 'Influent Feed'];

  void _openParameterSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        List<String> tempSelectedParameters = List.from(parametersToLog);
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Select Parameters to Log'),
              content: SingleChildScrollView(
                child: Column(
                  children: availableParameters.map((parameter) {
                    return CheckboxListTile(
                      title: Text(parameter),
                      value: tempSelectedParameters.contains(parameter),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            tempSelectedParameters.add(parameter);
                          } else {
                            tempSelectedParameters.remove(parameter);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      parametersToLog = tempSelectedParameters;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openTextInputDialog(String title, String initialValue, Function(String) onSubmitted) {
    TextEditingController controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter $title'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onSubmitted(controller.text);
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _openCstrUnitsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int tempCstrUnits = cstrUnits;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Select Number of CSTR Units'),
              content: DropdownButtonFormField<int>(
                value: tempCstrUnits,
                items: List.generate(8, (index) => index + 1)
                    .map((value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString()),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    tempCstrUnits = value ?? 1;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      cstrUnits = tempCstrUnits;
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openDataloggingFrequencyDialog() {
    TextEditingController controller = TextEditingController(text: dataloggingFrequency.toString());
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Set Datalogging Frequency (seconds)'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(hintText: 'Enter frequency in seconds'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  dataloggingFrequency = int.tryParse(controller.text) ?? dataloggingFrequency;
                });
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Project'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  _openTextInputDialog('Project Name', projectName, (value) {
                    setState(() {
                      projectName = value;
                    });
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Background color
                  minimumSize: Size(double.infinity, 50), // Button size
                ),
                child: Text(
                  projectName.isEmpty ? 'Enter Project Name' : projectName,
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openCstrUnitsDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Background color
                  minimumSize: Size(double.infinity, 50), // Button size
                ),
                child: Text(
                  'Number of CSTR Units',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _openTextInputDialog('Treatment Type', treatmentType, (value) {
                    setState(() {
                      treatmentType = value;
                    });
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Background color
                  minimumSize: Size(double.infinity, 50), // Button size
                ),
                child: Text(
                  treatmentType.isEmpty ? 'Enter Treatment Type' : treatmentType,
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openDataloggingFrequencyDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Background color
                  minimumSize: Size(double.infinity, 50), // Button size
                ),
                child: Text(
                  'Datalogging Frequency',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _openParameterSelectionDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Background color
                  minimumSize: Size(double.infinity, 50), // Button size
                ),
                child: Text(
                  'Select Parameters to Log',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              SizedBox(height: 16),
              Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: parametersToLog.map((parameter) {
                  return Chip(
                    label: Text(parameter),
                    onDeleted: () {
                      setState(() {
                        parametersToLog.remove(parameter);
                      });
                    },
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Save project settings
                    // Navigate back to the project settings home screen or display a success message
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Background color
                  minimumSize: Size(double.infinity, 50), // Button size
                ),
                child: Text(
                  'Save Project',
                  style:TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  MenuButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 50),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}