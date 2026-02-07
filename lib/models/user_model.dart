class UserModel {
  final String uid;
  final String email;
  final String role; // 'caregiver' or 'patient'
  final String? linkedCaregiverId; // IF patient: who monitors me?
  final List<String> linkedPatientIds; // IF caregiver: who do I monitor?

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    this.linkedCaregiverId,
    this.linkedPatientIds = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'linkedCaregiverId': linkedCaregiverId,
      'linkedPatientIds': linkedPatientIds,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      linkedCaregiverId: map['linkedCaregiverId'],
      linkedPatientIds: List<String>.from(map['linkedPatientIds'] ?? []),
    );
  }
}
