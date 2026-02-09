class UserModel {
  final String uid;
  final String email;
  final String role; // caregiver | patient

  final String? linkedCaregiverId;
  final List<String> linkedPatientIds;

  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.linkedCaregiverId,
    this.linkedPatientIds = const [],
    this.fcmToken,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'linkedCaregiverId': linkedCaregiverId,
      'linkedPatientIds': linkedPatientIds,
      'fcmToken': fcmToken,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      linkedCaregiverId: map['linkedCaregiverId'],
      linkedPatientIds: List<String>.from(map['linkedPatientIds'] ?? []),
      fcmToken: map['fcmToken'],
    );
  }
}
