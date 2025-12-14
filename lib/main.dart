import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IoT Smart Sensor System',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainScreen(),
    );
  }
}

// ============ VIRTUAL BLE SENSOR CLASS ============
class VirtualBLESensor {
  // Simulate sensor values
  double temperature = 25.0;
  double humidity = 60.0;

  // Connection status
  bool isAdvertising = false;
  bool isConnected = false;

  // Timer to update sensor values
  Timer? sensorTimer;

  // Callback when data changes
  Function(double, double)? onDataChanged;

  // Start simulating BLE advertising
  void startAdvertising() {
    isAdvertising = true;
    print("📡 VIRTUAL BLE SENSOR STARTED");
    print("   Device ID: VIRTUAL_SENSOR_001");
    print("   Service: Environmental Sensing");
    print("   Advertising temperature & humidity data");

    // Update sensor values every 3 seconds
    sensorTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      // Generate realistic sensor data
      temperature = 20.0 + Random().nextDouble() * 15; // 20-35°C
      humidity = 40.0 + Random().nextDouble() * 40; // 40-80%

      // Add small variations
      temperature += (Random().nextDouble() - 0.5) * 0.5;
      humidity += (Random().nextDouble() - 0.5) * 2;

      // Keep within reasonable limits
      temperature = temperature.clamp(15.0, 40.0).toDouble();
      humidity = humidity.clamp(30.0, 90.0).toDouble();

      print("📊 Sensor Updated: ${temperature.toStringAsFixed(1)}°C, ${humidity.toStringAsFixed(1)}%");

      // Notify listeners
      if (onDataChanged != null) {
        onDataChanged!(temperature, humidity);
      }
    });
  }

  // Simulate connecting to the sensor
  Future<void> connect() async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate connection time
    isConnected = true;
    print("✅ CONNECTED to Virtual BLE Sensor");
  }

  // Disconnect from sensor
  void disconnect() {
    isConnected = false;
    print("❌ DISCONNECTED from Virtual BLE Sensor");
  }

  // Stop advertising
  void stopAdvertising() {
    sensorTimer?.cancel();
    isAdvertising = false;
    print("🛑 VIRTUAL BLE SENSOR STOPPED");
  }
}
// ============ END VIRTUAL SENSOR ============

// Main Screen
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _widgetOptions = <Widget>[
    const DashboardScreen(),
    const ConnectScreen(),
    const HistoryScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Smart Sensor System'),
        centerTitle: true,
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bluetooth),
            label: 'Connect',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// ============ DASHBOARD SCREEN ============
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final VirtualBLESensor virtualSensor = VirtualBLESensor();
  double currentTemp = 0.0;
  double currentHum = 0.0;
  bool isLoading = false;
  Timer? syncTimer;
  List<Map<String, dynamic>> dataHistory = [];

  @override
  void initState() {
    super.initState();

    // Start virtual sensor when app starts
    virtualSensor.startAdvertising();

    // Listen for sensor data changes
    virtualSensor.onDataChanged = (temp, hum) {
      if (mounted) {
        setState(() {
          currentTemp = temp;
          currentHum = hum;

          // Add to history
          dataHistory.insert(0, {
            'temperature': temp,
            'humidity': hum,
            'timestamp': DateTime.now().toIso8601String(),
          });

          // Keep only last 10 readings
          if (dataHistory.length > 10) {
            dataHistory.removeLast();
          }
        });
      }
    };

    // Auto-sync to backend every 30 seconds
    syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (virtualSensor.isConnected) {
        _sendToBackend();
      }
    });
  }

  @override
  void dispose() {
    syncTimer?.cancel();
    virtualSensor.stopAdvertising();
    super.dispose();
  }

  // Connect to virtual sensor
  Future<void> _connectToSensor() async {
    setState(() => isLoading = true);
    await virtualSensor.connect();
    setState(() {
      isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Connected to Virtual BLE Sensor'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Send data to NestJS backend
  Future<void> _sendToBackend() async {
    setState(() => isLoading = true);

    // Use your laptop IP (change if needed)
    final uri = Uri.parse("http://192.168.1.14:3000/api/sensor-data");

    final data = {
      "temperature": currentTemp,
      "humidity": currentHum,
      "sensor_id": "VIRTUAL_SENSOR_001",
      "timestamp": DateTime.now().toIso8601String(),
      "device_type": "virtual_ble",
    };

    print("📤 Sending to backend: $data");

    try {
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 10));

      print("✅ Backend response: ${response.statusCode} - ${response.body}");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Synced to Cloud! (${response.statusCode})'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("❌ Error sending to backend: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Connection Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      virtualSensor.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color: virtualSensor.isConnected ? Colors.green : Colors.red,
                      size: 40,
                    ),
                    title: Text(
                      virtualSensor.isConnected
                          ? 'Connected to Sensor'
                          : 'Sensor Available',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Virtual BLE Sensor'),
                    trailing: Chip(
                      label: Text(virtualSensor.isConnected ? 'CONNECTED' : 'AVAILABLE'),
                      backgroundColor: virtualSensor.isConnected
                          ? Colors.green[100]
                          : Colors.blue[100],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: isLoading ? null : _connectToSensor,
                    icon: Icon(virtualSensor.isConnected ? Icons.link_off : Icons.link),
                    label: Text(virtualSensor.isConnected ? 'Disconnect' : 'Connect to Sensor'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: virtualSensor.isConnected ? Colors.red : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Sensor Data Display
          Row(
            children: [
              // Temperature Card
              Expanded(
                child: Card(
                  elevation: 4,
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.thermostat, size: 50, color: Colors.red),
                        const SizedBox(height: 10),
                        Text(
                          '${currentTemp.toStringAsFixed(1)}°C',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                        const Text('Temperature', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: (currentTemp - 15) / 25, // 15-40°C range
                          backgroundColor: Colors.red[100],
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Humidity Card
              Expanded(
                child: Card(
                  elevation: 4,
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.water_drop, size: 50, color: Colors.blue),
                        const SizedBox(height: 10),
                        Text(
                          '${currentHum.toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                        const Text('Humidity', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: currentHum / 100,
                          backgroundColor: Colors.blue[100],
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action Buttons
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _sendToBackend,
                          icon: isLoading
                              ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                              : const Icon(Icons.cloud_upload),
                          label: isLoading
                              ? const Text('Syncing...')
                              : const Text('Sync to Cloud'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Refresh data
                            setState(() {
                              currentTemp = 20.0 + Random().nextDouble() * 15;
                              currentHum = 40.0 + Random().nextDouble() * 40;
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Sensor'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Data History
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Sensor Readings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 200,
                    child: dataHistory.isEmpty
                        ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sensors, size: 50, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('Waiting for sensor data...'),
                          Text('Connect to sensor first', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                        : ListView.builder(
                      itemCount: dataHistory.length,
                      itemBuilder: (context, index) {
                        final reading = dataHistory[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: const Icon(Icons.thermostat, color: Colors.blue),
                          ),
                          title: Text(
                            '${reading['temperature'].toStringAsFixed(1)}°C • ${reading['humidity'].toStringAsFixed(1)}%',
                          ),
                          subtitle: Text(
                            reading['timestamp'].toString().substring(11, 19),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.upload, size: 20),
                            onPressed: () {
                              // Send individual reading
                              currentTemp = reading['temperature'];
                              currentHum = reading['humidity'];
                              _sendToBackend();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ CONNECT SCREEN ============
class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_searching, size: 100, color: Colors.blue),
          const SizedBox(height: 20),
          const Text(
            'BLE Device Scanner',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Scanning for nearby BLE devices...',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 30),

          // Virtual Device Card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.device_hub, color: Colors.green, size: 40),
                    title: Text('Virtual BLE Sensor', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ID: VIRTUAL_SENSOR_001\nService: Environmental Sensing'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Go back to dashboard and connect
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('Connect This Device'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Info Box
          Container(
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(height: 10),
                Text(
                  'This is a Virtual BLE Sensor',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  'In a real implementation, this would be an ESP32/Arduino with actual sensors sending data via Bluetooth.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ HISTORY SCREEN ============
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Data History from Backend',
        style: TextStyle(fontSize: 20),
      ),
    );
  }
}