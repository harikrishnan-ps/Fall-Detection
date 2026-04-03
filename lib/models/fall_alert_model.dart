import 'package:cloud_firestore/cloud_firestore.dart';

class FallAlertModel {
  final String id;
  final String patientId;
  final double? latitude;   // nullable — ESP32 may not have GPS
  final double? longitude;  // nullable — ESP32 may not have GPS
  final DateTime timestamp;
  final bool isResolved;
  final String? encryptedPayload;
  final String? decryptedMessage; // set by app after decryption

  FallAlertModel({
    required this.id,
    required this.patientId,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.isResolved = false,
    this.encryptedPayload,
    this.decryptedMessage,
  });

  /// Whether this alert has valid GPS coordinates.
  bool get hasLocation =>
      latitude != null && longitude != null &&
      !(latitude == 0.0 && longitude == 0.0);

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'isResolved': isResolved,
      if (decryptedMessage != null) 'decryptedMessage': decryptedMessage,
    };
  }

  /// Extract "lat,lng" from a decrypted message like:
  ///   "FALL 9.827807,76.511563 @ 2026-04-03T03:16:50Z"
  static (double?, double?) _parseCoords(String? msg) {
    if (msg == null) return (null, null);
    // Match an optional sign, digits, dot, digits pair separated by a comma
    final re = RegExp(r'(-?\d+\.\d+),(-?\d+\.\d+)');
    final m = re.firstMatch(msg);
    if (m == null) return (null, null);
    return (double.tryParse(m.group(1)!), double.tryParse(m.group(2)!));
  }

  factory FallAlertModel.fromMap(Map<String, dynamic> map) {
    // Accept both ESP32 field name ('data') and legacy ('encryptedPayload')
    final rawPayload =
        map['encryptedPayload'] as String? ?? map['data'] as String?;

    final decryptedMessage = map['decryptedMessage'] as String?;

    // GPS — prefer explicit Firestore fields; fall back to coords embedded
    // in the decrypted message (new firmware: "FALL lat,lng @ timestamp")
    double? lat = map['latitude'] != null
        ? (map['latitude'] as num).toDouble()
        : null;
    double? lng = map['longitude'] != null
        ? (map['longitude'] as num).toDouble()
        : null;

    if (lat == null || lng == null) {
      final (parsedLat, parsedLng) = _parseCoords(decryptedMessage);
      lat ??= parsedLat;
      lng ??= parsedLng;
    }

    return FallAlertModel(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      latitude: lat,
      longitude: lng,
      encryptedPayload: rawPayload,
      decryptedMessage: decryptedMessage,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isResolved: map['isResolved'] ?? false,
    );
  }
}

