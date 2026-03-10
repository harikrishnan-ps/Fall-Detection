class AppConstants {
  static const String usersCollection = 'users';
  static const String alertsCollection = 'alerts';

  static const String roleCaregiver = 'caregiver';
  static const String rolePatient = 'patient';

  /// The Firebase account used by the hardware device (ESP32 + MPU6050).
  /// It writes encrypted fall alerts to the [alertsCollection] with an
  /// 'encryptedPayload' (hex) field. The [NotificationService.listenToHardwareAlerts]
  /// listener watches for these documents regardless of patientId.
  static const String hardwareEmail = 'fall@gmail.com';
}
