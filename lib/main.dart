import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/location_service.dart';
import 'screens/wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
  } catch (e) {
    // If this fails → your google-services.json / gradle is wrong
    debugPrint("FATAL: Firebase initialization failed: $e");
    rethrow;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // CORE SERVICES
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => FirestoreService()),
        Provider(create: (_) => LocationService()),

        // AUTH STATE STREAM
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