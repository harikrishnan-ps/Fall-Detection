import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/constants.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User>(context);
    final firestore = Provider.of<FirestoreService>(context);

    Future<void> setRole(String role) async {
      await firestore.saveUser(UserModel(
        uid: user.uid,
        email: user.email ?? '',
        role: role,
      ));
      // Wrapper will re-evaluate on next build via Stream or simple reload, 
      // but StreamBuilder in Wrapper might not auto-refresh if it's FutureBuilder.
      // Ideally we rely on a Stream for UserData, but for simplicity we can trigger a state change or just let the FutureBuilder rebuild if the parent rebuilds. 
      // Actually, FutureBuilder won't rebuild automatically unless the future is re-created.
      // A better way is using a Stream for the UserData.
      // For this MVP, we force a re-check or just setState (but we are in stateless).
      // We will perform a simple hot-restart or better yet, make Wrapper use Stream.
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Role')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => setRole(AppConstants.roleCaregiver),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
              child: const Text('I am a CAREGIVER'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => setRole(AppConstants.rolePatient),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20)),
              child: const Text('I am a PATIENT'),
            ),
          ],
        ),
      ),
    );
  }
}
