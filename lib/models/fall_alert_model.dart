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

  factory FallAlertModel.fromMap(Map<String, dynamic> map) {
    // Accept both ESP32 field name ('data') and legacy ('encryptedPayload')
    final rawPayload =
        map['encryptedPayload'] as String? ?? map['data'] as String?;

    // GPS — may be absent when ESP32 GPS is not working
    final lat = map['latitude'] != null
        ? (map['latitude'] as num).toDouble()
        : null;
    final lng = map['longitude'] != null
        ? (map['longitude'] as num).toDouble()
        : null;

    return FallAlertModel(
      id: map['id'] ?? '',
      patientId: map['patientId'] ?? '',
      latitude: lat,
      longitude: lng,
      encryptedPayload: rawPayload,
      decryptedMessage: map['decryptedMessage'] as String?,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      isResolved: map['isResolved'] ?? false,
    );
  }
}

