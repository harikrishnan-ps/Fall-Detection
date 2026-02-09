import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  GoogleMapController? _mapController;
  // Set<Marker> _markers = {}; // Removed state, derived from stream
  // LatLng? _initialPosition; // Removed state

  late Stream<List<FallAlertModel>> _alertsStream;

  @override
  void initState() {
    super.initState();
    final firestore = Provider.of<FirestoreService>(context, listen: false);
    _alertsStream = firestore.getAlertsForPatient(widget.patientId);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers(List<FallAlertModel> alerts) {
    return alerts.map((alert) {
      return Marker(
        markerId: MarkerId(alert.id),
        position: LatLng(alert.latitude, alert.longitude),
        infoWindow: InfoWindow(
          title: 'Fall Detected',
          snippet: DateFormat('MMM d, HH:mm').format(alert.timestamp),
        ),
      );
    }).toSet();
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
                child: GoogleMap(
                  onMapCreated: (c) => _mapController = c,

                  initialCameraPosition: CameraPosition(
                    target: initialPos,
                    zoom: 15,
                  ),

                  markers: markers,

                  myLocationEnabled: true,
                  zoomControlsEnabled: true,
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
