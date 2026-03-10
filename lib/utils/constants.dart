class AppConstants {
  static const String usersCollection = 'users';
  static const String alertsCollection = 'alerts';

  static const String roleCaregiver = 'caregiver';
  static const String rolePatient = 'patient';

  /// The Firebase account used by the hardware device (ESP32 + MPU6050).
  /// It writes encrypted fall alerts to the [alertsCollection] with a
  /// 'data' (hex ciphertext) + 'secure: true' structure.
  static const String hardwareEmail = 'fall@gmail.com';

  /// The Firestore UID of the hardware patient account ('fall@gmail.com').
  /// Used when the ESP32 omits or mis-fills the patientId field.
  static const String hardwarePatientId = 'pDbouxJfEbYDLcnsYaNqv9HjvQ12';
}
