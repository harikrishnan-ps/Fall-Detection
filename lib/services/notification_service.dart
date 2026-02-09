
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // 1. Request permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted permission');
      
      // 2. Get Token
      // await registerToken(); <--- MISTAKE WAS HERE, REMOVED RECURSION
      String? token = await _firebaseMessaging.getToken();
      
      if (token != null) {
         await saveTokenToFirestore(token);
      }

      // 3. Handle Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          // You could show a local notification here if you want
        }
      });

    } else {
      debugPrint('❌ User declined or has not accepted permission');
    }
  }

  static Future<void> saveTokenToFirestore(String token) async {
    try {
      debugPrint("🟢 FCM Token: $token");

      String uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token}); // Changed from oneSignalId to fcmToken

      debugPrint("✅ FCM Token saved to Firestore");

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': newToken});
        debugPrint("♻️ FCM Token refreshed and saved");
      });

    } catch (e) {
      debugPrint("🔥 saveTokenToFirestore error: $e");
    }
  }
}
