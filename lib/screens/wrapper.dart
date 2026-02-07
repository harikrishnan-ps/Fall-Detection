import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'auth/login_screen.dart';
import 'auth/role_selection_screen.dart';
import 'caregiver/caregiver_dashboard.dart';
import 'patient/patient_home_screen.dart';
import '../utils/constants.dart';

class Wrapper extends StatelessWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    final firestore = Provider.of<FirestoreService>(context);

    if (user == null) {
      return const LoginScreen();
    }

    // Authenticated, check Role
    return StreamBuilder<UserModel?>(
      stream: firestore.streamUser(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          final userModel = snapshot.data!;
          if (userModel.role == AppConstants.roleCaregiver) {
            return const CaregiverDashboard();
          } else if (userModel.role == AppConstants.rolePatient) {
            return const PatientHomeScreen();
          }
        }

        // No role set or user doc missing -> Go to Role Selection
        return const RoleSelectionScreen();
      },
    );
  }
}
