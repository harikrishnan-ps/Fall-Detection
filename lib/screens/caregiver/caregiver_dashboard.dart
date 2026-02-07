import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'patient_detail_screen.dart';

class CaregiverDashboard extends StatelessWidget {
  // Helper to use StreamBuilder for user data again? Or just FutureBuilder once.
  // Let's use standard StatelessWidget and StreamBuilder inside.
  const CaregiverDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User>(context);
    final authService = Provider.of<AuthService>(context);
    final firestore = Provider.of<FirestoreService>(context);

    void showAddPatientDialog() {
      final controller = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Patient'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Patient ID (UID)'),
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              child: const Text('Add'),
              onPressed: () async {
                try {
                  await firestore.linkPatient(user.uid, controller.text.trim());
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caregiver Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => authService.signOut())
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: firestore.streamUser(user.uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final userData = snapshot.data!;
          final patientIds = userData.linkedPatientIds;

          if (patientIds.isEmpty) {
            return const Center(child: Text('No patients linked. Click + to add.'));
          }

          return ListView.builder(
            itemCount: patientIds.length,
            itemBuilder: (context, index) {
              final pid = patientIds[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text('Patient ID: ...${pid.substring(0, 6)}...'), // Shortened for UI
                subtitle: Text(pid),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailScreen(patientId: pid)));
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: showAddPatientDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// Just a typo fix in class name above: 'StatelessWithStream' -> 'StatelessWidget'
// I'll fix it in the file content directly.
