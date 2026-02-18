import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  // You can initialize logic here if needed, but simple notifications work automatically.
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
      });

    } else {
      debugPrint('❌ User declined or has not accepted permission');
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
