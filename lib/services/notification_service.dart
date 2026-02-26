import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../Encryption/ascon.dart';
import '../utils/hex_utils.dart';

// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  
  // Initialize local notifications in background isolate
  final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotif.initialize(const InitializationSettings(android: androidSettings));
  
  await NotificationService.handleEncryptedMessage(message, localNotif);
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDesc = 'This channel is used for important notifications.';

  static Future<void> initialize() async {
    // 1. Setup Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Request Permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );


    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted permission');
      
      // 3. Initialize Local Notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const InitializationSettings initSettings =
          InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(initSettings);

      // 4. Create Notification Channel (Android)
      final AndroidNotificationChannel channel = const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 5. Get Token and Save
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
         await saveTokenToFirestore(token);
      }


      // 6. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        // If notification is present, show local notification
        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDesc,
                icon: '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
                fullScreenIntent: true, // Optional: for really important alerts
              ),
            ),
          );
        }

        // Handle customized encrypted data message
        handleEncryptedMessage(message, _localNotifications);
      });

    } else {
      debugPrint('❌ User declined or has not accepted permission');
    }
  }

  static Future<void> handleEncryptedMessage(RemoteMessage message, FlutterLocalNotificationsPlugin localNotif) async {
    final data = message.data;
    if (data['secure'] == true || data['secure'] == 'true') {
      final ciphertextHex = data['data'] as String?;
      if (ciphertextHex == null) return;

      final ascon = Ascon();
      // Using exactly the example key and nonce from encryption_test_screen.dart
      final keyBytes = HexUtils.fromHex("000102030405060708090a0b0c0d0e0f");
      final nonceBytes = HexUtils.fromHex("a0a1a2a3a4a5a6a7a8a9aaabacadaeaf");
      final ciphertextBytes = HexUtils.fromHex(ciphertextHex);

      if (keyBytes == null || nonceBytes == null || ciphertextBytes == null) {
        debugPrint("Encrypted payload has invalid hex data.");
        return;
      }

      try {
        final plaintext = ascon.decrypt(
          ciphertext: ciphertextBytes,
          key: keyBytes,
          nonce: nonceBytes,
          associatedData: Uint8List(0),
        );
        
        if (plaintext != null) {
          await localNotif.show(
            DateTime.now().millisecond,
            "Fall Detected",
            "An emergency fall event has been detected securely.",
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                _channelName,
                channelDescription: _channelDesc,
                icon: '@mipmap/ic_launcher',
                importance: Importance.max,
                priority: Priority.high,
                fullScreenIntent: true,
              ),
            ),
          );
        } else {
          debugPrint("Failed to decrypt secure message (tag mismatch).");
        }
      } catch (e) {
        debugPrint("Decryption error: $e");
      }
    }
  }

  static Future<void> updateToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await saveTokenToFirestore(token);
    }
  }

  static Future<void> saveTokenToFirestore(String token) async {
    try {
      debugPrint("🟢 FCM Token: $token");
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token}); 

      debugPrint("✅ FCM Token saved to Firestore");

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
         await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': newToken});
        debugPrint("♻️ FCM Token refreshed and saved");
      });

    } catch (e) {
      debugPrint("🔥 saveTokenToFirestore error: $e");
    }
  }
}
