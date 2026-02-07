import 'package:cloud_firestore/cloud_firestore.dart';

class FallAlertModel {
  final String id;
  final String patientId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isResolved;

  FallAlertModel({
    required this.id,
    required this.patientId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isResolved = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'isResolved': isResolved,
    };
  }

  factory FallAlertModel.fromMap(Map<String, dynamic> map) {
  return FallAlertModel(
    id: map['id'] ?? '',

    patientId: map['patientId'] ?? '',

    latitude: (map['latitude'] as num).toDouble(),

    longitude: (map['longitude'] as num).toDouble(),

    timestamp: map['timestamp'] is Timestamp
        ? (map['timestamp'] as Timestamp).toDate()
        : DateTime.now(),

    isResolved: map['isResolved'] ?? false,
  );
}

}
