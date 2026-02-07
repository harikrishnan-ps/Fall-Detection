import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/fall_alert_model.dart';
import '../../services/firestore_service.dart';

class PatientDetailScreen extends StatelessWidget {
  final String patientId;

  const PatientDetailScreen({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Patient Details & Logs')),

      body: StreamBuilder<List<FallAlertModel>>(
        stream: firestore.getAlertsForPatient(patientId),

        builder: (context, snapshot) {

          // 1. Loading
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final alerts = snapshot.data ?? [];

          // 3. No data
          if (alerts.isEmpty) {
            return const Center(child: Text("No falls recorded yet"));
          }

          // Build markers safely
          final markers = alerts.map((alert) {
            return Marker(
              markerId: MarkerId(alert.id),
              position: LatLng(alert.latitude, alert.longitude),
              infoWindow: InfoWindow(
                title: 'Fall Detected',
                snippet: DateFormat('MMM d, HH:mm').format(alert.timestamp),
              ),
            );
          }).toSet();

          // Center map on latest alert
          final initialPosition = LatLng(
            alerts.first.latitude,
            alerts.first.longitude,
          );

          return Column(
            children: [

              // ================= MAP =================
              SizedBox(
                height: 300,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialPosition,
                    zoom: 15,
                  ),
                  markers: markers,
                  myLocationEnabled: true,
                  zoomControlsEnabled: true,
                ),
              ),

              const Divider(),

              // ============== LOG TITLE ==============
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
