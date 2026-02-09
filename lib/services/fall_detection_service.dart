import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/location_service.dart';
import '../services/firestore_service.dart';
import '../models/fall_alert_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FallDetectionService {

  StreamSubscription? _sub;
  bool _inCooldown = false;

  final LocationService _location = LocationService();
  final FirestoreService _firestore = FirestoreService();

  void start() {
    _sub = accelerometerEvents.listen(_onData);
  }

  void stop() {
    _sub?.cancel();
  }

  void _onData(AccelerometerEvent e) async {

    double magnitude =
        (e.x * e.x + e.y * e.y + e.z * e.z).abs();

    // SIMPLE THRESHOLD – you can improve later
    if (magnitude > 35 && !_inCooldown) {
      await _handleFall();
    }
  }

  Future<void> _handleFall() async {

    _inCooldown = true;

    try {
      final pos = await _location.getCurrentLocation();

      final uid = FirebaseAuth.instance.currentUser!.uid;

      final alert = FallAlertModel(
        id: '',
        patientId: uid,
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
      );

      await _firestore.reportFall(alert);

    } catch (_) {}

    // 2 MINUTE COOLDOWN
    Future.delayed(const Duration(minutes: 2), () {
      _inCooldown = false;
    });
  }
}
