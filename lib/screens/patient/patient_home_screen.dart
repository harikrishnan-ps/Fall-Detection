import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/fall_alert_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';

// NEW IMPORT
import '../../services/fall_detection_service.dart';

class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {

  bool _isSimulatingFall = false;

  // ───────────── NEW ─────────────
  late FallDetectionService _fallService;
  // ───────────────────────────────

  @override
  void initState() {
    super.initState();

    // START REAL DETECTION
    _fallService = FallDetectionService();
    _fallService.start();
  }

  @override
  void dispose() {
    _fallService.stop();
    super.dispose();
  }

  // ───────────── SIMULATE FALL (KEEPED) ─────────────
  Future<void> _simulateFall() async {
    setState(() => _isSimulatingFall = true);

    final user = FirebaseAuth.instance.currentUser;
    final firestore =
        Provider.of<FirestoreService>(context, listen: false);
    final locationService =
        Provider.of<LocationService>(context, listen: false);

    try {
      if (user == null) throw "User not logged in";

      print("STEP 1 - requesting location");
      final pos = await locationService.getCurrentLocation();
      print("STEP 2 - location received: ${pos.latitude}, ${pos.longitude}");

      final alert = FallAlertModel(
        id: "",
        patientId: user.uid,
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
        isResolved: false,
      );

      await firestore.reportFall(alert);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('FALL DETECTED! Alert sent to Caregiver.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reporting fall: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulatingFall = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          )
        ],
      ),

      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(Icons.health_and_safety,
                size: 100, color: Colors.green),

            const SizedBox(height: 20),

            const Text(
              'Monitoring Active',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              child: Column(
                children: [
                  const Text(
                      'Your Device ID (Share with Caregiver):'),
                  SelectableText(
                    user?.uid ?? "unknown",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            _isSimulatingFall
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: 220,
                    height: 60,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      icon: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'SIMULATE FALL',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18),
                      ),
                      onPressed: _simulateFall,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
