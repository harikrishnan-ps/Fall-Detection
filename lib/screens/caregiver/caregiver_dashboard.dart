import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import 'patient_detail_screen.dart';
import '../encryption_test_screen.dart';

class CaregiverDashboard extends StatefulWidget {
  const CaregiverDashboard({Key? key}) : super(key: key);

  @override
  State<CaregiverDashboard> createState() => _CaregiverDashboardState();
}

class _CaregiverDashboardState extends State<CaregiverDashboard> {

  @override
  void initState() {
    super.initState();

    // Notifications are initialized in main.dart, but we can re-check permissions here if needed.
    // NotificationService.initialize();
  }

  @override
  Widget build(BuildContext context) {

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      return const Scaffold(
        body: Center(child: Text("Not logged in")),
      );
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    void showAddPatientDialog() {
      final controller = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Patient'),

          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Patient ID (UID)',
            ),
          ),

          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),

            ElevatedButton(
              child: const Text('Add'),
              onPressed: () async {
                try {
                  await firestore.linkPatient(
                    firebaseUser.uid,
                    controller.text.trim(),
                  );

                  if (context.mounted) Navigator.pop(context);

                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          )
        ],
      ),

      body: StreamBuilder<UserModel?>(
        stream: firestore.streamUser(firebaseUser.uid),

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text("No user data"),
            );
          }

          final userData = snapshot.data!;
          final patientIds = userData.linkedPatientIds;

          if (patientIds.isEmpty) {
            return const Center(
              child: Text('No patients linked. Click + to add.'),
            );
          }

          return ListView.builder(
            itemCount: patientIds.length,

            itemBuilder: (context, index) {

              final pid = patientIds[index];
              final customName = userData.patientNames?[pid];

              final safeId = pid.length > 6
                  ? pid.substring(0, 6)
                  : pid;

              final displayName = customName != null && customName.isNotEmpty 
                  ? customName 
                  : 'Patient ID: ...$safeId...';

              return ListTile(
                leading: const Icon(Icons.person),

                title: Text(displayName),

                subtitle: Text(pid),

                trailing: const Icon(Icons.arrow_forward_ios),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PatientDetailScreen(patientId: pid),
                    ),
                  );
                },
                onLongPress: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit),
                            title: const Text('Rename Patient'),
                            onTap: () {
                              Navigator.pop(context);
                              
                              final nameController = TextEditingController(text: customName);
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Rename Patient'),
                                  content: TextField(
                                    controller: nameController,
                                    decoration: const InputDecoration(labelText: 'Patient Name'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await firestore.renamePatient(
                                            firebaseUser.uid, 
                                            pid, 
                                            nameController.text.trim()
                                          );
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Patient renamed successfully')),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.delete, color: Colors.red),
                            title: const Text('Remove Patient', style: TextStyle(color: Colors.red)),
                            onTap: () {
                              Navigator.pop(context);
                              
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove Patient?'),
                                  content: const Text('Are you sure you want to unlink this patient?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await firestore.unlinkPatient(firebaseUser.uid, pid);
                                          if (context.mounted) Navigator.pop(context);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Patient removed successfully')),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Error: $e')),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          FloatingActionButton(
            heroTag: "save",
            onPressed: () => NotificationService.initialize(),
            child: const Icon(Icons.save),
          ),

          const SizedBox(height: 10),

          FloatingActionButton(
            heroTag: "test_enc",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EncryptionTestScreen()),
              );
            },
            child: const Icon(Icons.security),
          ),

          const SizedBox(height: 10),

          FloatingActionButton(
            heroTag: "add",
            onPressed: showAddPatientDialog,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
