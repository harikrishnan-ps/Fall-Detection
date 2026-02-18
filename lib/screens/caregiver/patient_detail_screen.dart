import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/fall_alert_model.dart';
import '../../services/firestore_service.dart';

class PatientDetailScreen extends StatefulWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {



  late Stream<List<FallAlertModel>> _alertsStream;

  @override
  void initState() {
    super.initState();
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    _alertsStream = firestore.getAlertsForPatient(widget.patientId);
  }

  @override
  void dispose() {

    super.dispose();
  }

  List<Marker> _buildMarkers(List<FallAlertModel> alerts) {
    return alerts.map((alert) {
      return Marker(
        point: LatLng(alert.latitude, alert.longitude),
        width: 40,
        height: 40,
        child: const Icon(
          Icons.location_on,
          color: Colors.red,
          size: 40,
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Patient Details & Logs')),

      body: StreamBuilder<List<FallAlertModel>>(
        stream: _alertsStream, // Fixed: Stream is stable now

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final alerts = snapshot.data ?? [];

          if (alerts.isEmpty) {
            return const Center(child: Text("No falls recorded yet"));
          }

          // Declarative markers
          final markers = _buildMarkers(alerts);
          final initialPos = LatLng(alerts.first.latitude, alerts.first.longitude);

          return Column(
            children: [

              // ============== MAP ==============
              SizedBox(
                height: 300,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: initialPos,
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.fall_detection_app',
                    ),
                    MarkerLayer(
                      markers: markers,
                    ),
                  ],
                ),
              ),

              const Divider(),

              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "Event Logs",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // ============== LIST ==============
              Expanded(
                child: ListView.builder(
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {

                    final alert = alerts[index];

                    return Card(
                      color: Colors.red[50],
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),

                      child: ListTile(
                        leading: const Icon(
                          Icons.warning,
                          color: Colors.red,
                        ),

                        title: const Text("Fall Detected"),

                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [

                            Text(
                              "Time: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(alert.timestamp)}",
                            ),

                            Text(
                              "Location: ${alert.latitude.toStringAsFixed(4)}, "
                              "${alert.longitude.toStringAsFixed(4)}",
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
