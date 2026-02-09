import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';

import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/location_service.dart';
import 'screens/wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();

    // ─────────────────────────────────────
    // NOTIFICATION INITIALIZATION
    // ─────────────────────────────────────
    await NotificationService.initialize();

  } catch (e) {
    debugPrint("FATAL: Firebase initialization failed: $e");
    // rethrow; // Better not to crash the whole app if init fails, but log it.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
        Provider(create: (_) => LocationService()),

        StreamProvider<User?>(
          create: (context) =>
              context.read<AuthService>().authStateChanges,
          initialData: null,
        ),
      ],

      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Fall Detection App',

        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),

        home: const Wrapper(),
      ),
    );
  }
}
