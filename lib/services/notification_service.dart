import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import '../Encryption/ascon.dart';
import '../utils/hex_utils.dart';
import '../main.dart'; // import navigatorKey
import '../utils/constants.dart';
import 'dart:async';

// Top-level background handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
  
  // Initialize local notifications in background isolate
  final FlutterLocalNotificationsPlugin localNotif = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotif.initialize(const InitializationSettings(android: androidSettings));
  
  if (message.data.containsKey('encryptedPayload')) {
    String decrypted = NotificationService.processEncryptedAlert(message.data['encryptedPayload']);
    
    // Show a high-importance local notification with the decrypted message
    await localNotif.show(
      DateTime.now().millisecond,
      "EMERGENCY",
      "Fall detected: $decrypted",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationService._channelId,
          NotificationService._channelName,
          channelDescription: NotificationService._channelDesc,
          icon: '@mipmap/ic_launcher',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  } else {
    // Fallback to older secure handler
    await NotificationService.handleEncryptedMessage(message, localNotif);
  }
}


class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const String _channelId = 'high_importance_channel';
  static const String _channelName = 'High Importance Notifications';
  static const String _channelDesc = 'This channel is used for important notifications.';

  // The Decryption Pipeline
  static String processEncryptedAlert(String hexCiphertext) {
    try {
      // 1. Convert the hex string back to raw bytes using existing util
      Uint8List? cipherBytes = HexUtils.fromHex(hexCiphertext);
      if (cipherBytes == null) return "ERROR: Invalid hex data.";

      // exactly the example key and nonce from encryption_test_screen.dart
      final keyBytes = HexUtils.fromHex("000102030405060708090a0b0c0d0e0f");
      final nonceBytes = HexUtils.fromHex("a0a1a2a3a4a5a6a7a8a9aaabacadaeaf");
      
      if (keyBytes == null || nonceBytes == null) return "ERROR: Invalid key/nonce.";

      final ascon = Ascon();

      // 2. DECRYPT USING ASCON
      Uint8List? decryptedBytes = ascon.decrypt(
        ciphertext: cipherBytes,
        key: keyBytes,
        nonce: nonceBytes,
        associatedData: Uint8List(0),
      );
      
      if (decryptedBytes == null) {
        return "ERROR: Verification failed (tag mismatch).";
      }
      
      // 3. Convert the decrypted bytes back to a readable string
      String plaintext = utf8.decode(decryptedBytes);
      debugPrint("Decrypted Alert: $plaintext"); 
      
      return plaintext;
      
    } catch (e) {
      debugPrint("Decryption failed: $e");
      return "ERROR: Could not decrypt emergency alert.";
    }
  }

  static void showFallAlertDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to acknowledge it
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Text("EMERGENCY", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Fall detected!\n\nDetails:\n$message",
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Acknowledge", style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(context).pop();
                // You could also add logic here to update the Firestore document's 
                // 'isResolved' field to true!
              },
            ),
          ],
        );
      },
    );
  }

  // ---------- Subscription handles ----------
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _alertSubscription;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _hardwareAlertSubscription;

  // Tracks doc IDs we have already processed (prevents double-fire on
  // subscription init and duplicate documents).
  static final Set<String> _processedDocIds = {};

  // ─────────────────────────────────────────────────────────────────────────
  // HARDWARE LISTENER
  // Watches the entire 'alerts' collection for newly-added documents.
  //
  // ⚠️  Why no orderBy('timestamp'):
  //   The ESP32 does NOT include a 'timestamp' field in its documents.
  //   Firestore silently excludes documents without the ordered field, so
  //   using orderBy('timestamp') means the ESP32 alert is never received.
  //
  // ⚠️  Field name difference:
  //   ESP32 writes: { data: "<hex>", secure: true, ... }
  //   Legacy path:  { encryptedPayload: "<hex>", ... }
  //   Both are handled below.
  // ─────────────────────────────────────────────────────────────────────────
  static void listenToHardwareAlerts() {
    _hardwareAlertSubscription?.cancel();
    _processedDocIds.clear(); // reset on fresh subscription

    debugPrint("🔊 [HW Listener] Starting hardware alert listener on '${AppConstants.alertsCollection}'...");

    // We only want documents added AFTER we start listening, not historical
    // ones. Because we can't use orderBy('timestamp') (ESP32 omits it), we
    // mark all already-existing docs as processed on the first snapshot so
    // the initial load is always skipped.
    bool initialSnapshotConsumed = false;

    _hardwareAlertSubscription = FirebaseFirestore.instance
        .collection(AppConstants.alertsCollection)
        .snapshots()
        .listen((snapshot) {

      // On the very first event, Firestore delivers all existing documents
      // as 'added'. We mark them all as seen without processing them.
      if (!initialSnapshotConsumed) {
        initialSnapshotConsumed = true;
        for (var doc in snapshot.docs) {
          _processedDocIds.add(doc.id);
        }
        debugPrint("[HW Listener] Initial snapshot consumed — ${snapshot.docs.length} existing docs skipped.");
        return;
      }

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;

          // Skip if we've already handled this document
          if (_processedDocIds.contains(docId)) continue;
          _processedDocIds.add(docId);

          final data = change.doc.data();
          debugPrint("[HW Listener] New doc received: $docId | fields: ${data?.keys.toList()}");

          if (data == null) continue;

          // ── Path 1: ESP32 format → { data: "<hex>", secure: true }
          if (data['secure'] == true && data.containsKey('data')) {
            final String hexPayload = data['data'] as String;
            debugPrint("[HW Listener] 'data' field (secure) found — decrypting...");
            _handleDecryptedAlert(hexPayload);

          // ── Path 2: Legacy format → { encryptedPayload: "<hex>" }
          } else if (data.containsKey('encryptedPayload')) {
            final String hexPayload = data['encryptedPayload'] as String;
            debugPrint("[HW Listener] 'encryptedPayload' field found — decrypting...");
            _handleDecryptedAlert(hexPayload);

          } else {
            debugPrint("[HW Listener] No recognised encrypted field in doc $docId — skipping.");
          }
        }
      }
    }, onError: (e) {
      debugPrint("[HW Listener] Error: $e");
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT-LINKED LISTENER
  // Watches alerts for specific linked patient IDs. Useful when hardware sends
  // a proper patientId field.
  // ─────────────────────────────────────────────────────────────────────────
  static void listenToFirestoreAlerts(List<String> patientIds) {
    _alertSubscription?.cancel();
    if (patientIds.isEmpty) return;

    // Use a start timestamp just before now to catch new documents only,
    // but with a small buffer to avoid clock-skew race conditions.
    final listenSince = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(seconds: 5)),
    );

    _alertSubscription = FirebaseFirestore.instance
        .collection(AppConstants.alertsCollection)
        .where('patientId', whereIn: patientIds)
        .where('timestamp', isGreaterThan: listenSince)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;
          if (_processedDocIds.contains(docId)) continue;
          _processedDocIds.add(docId);

          final data = change.doc.data();
          if (data != null && data.containsKey('encryptedPayload')) {
            final String hexPayload = data['encryptedPayload'] as String;
            _handleDecryptedAlert(hexPayload);
          }
        }
      }
    }, onError: (e) {
      debugPrint("[Patient Listener] Error: $e");
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED DECRYPT + DISPLAY HELPER
  // ─────────────────────────────────────────────────────────────────────────
  static void _handleDecryptedAlert(String hexPayload) {
    final String decryptedMessage = processEncryptedAlert(hexPayload);
    debugPrint("[Alert] Decrypted message: $decryptedMessage");

    // Show local notification (works in foreground, background, and when
    // the screen is locked).
    _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      "⚠️ EMERGENCY — Fall Detected",
      decryptedMessage,
      const NotificationDetails(
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

    // Show an in-app alert dialog if the app is in the foreground.
    final context = navigatorKey.currentContext;
    if (context != null) {
      showFallAlertDialog(context, decryptedMessage);
    } else {
      debugPrint("[Alert] Navigator context is null — dialog skipped (app may be in background).");
    }
  }

  /// Cancel all active Firestore subscriptions.
  static void cancelAllSubscriptions() {
    _alertSubscription?.cancel();
    _hardwareAlertSubscription?.cancel();
    _processedDocIds.clear();
    debugPrint("[Subscriptions] All alert subscriptions cancelled.");
  }

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

        // Handle purely local notification if there is normal payload structure
        if (notification != null && android != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            const NotificationDetails(
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

        // Handle completely custom encryptedPayload
        if (message.data.containsKey('encryptedPayload')) {
          String hexPayload = message.data['encryptedPayload'];
          String decryptedMessage = processEncryptedAlert(hexPayload);
          
          // Show an immediate alert dialog if the app is open via navigatorKey
          final context = navigatorKey.currentContext;
          if (context != null) {
            showFallAlertDialog(context, decryptedMessage);
          } else {
             debugPrint("WARNING: Alert Dialog skipped because Navigator Context is null");
          }
        }

        // Handle customized secure data message (fallback)
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
