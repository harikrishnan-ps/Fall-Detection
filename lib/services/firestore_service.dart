import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/fall_alert_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ───────────────── USER PROFILE ─────────────────

  // ✅ THIS METHOD FIXES YOUR CURRENT BUILD ERROR
  Future<void> saveUser(UserModel user) async {
    await _db
        .collection(AppConstants.usersCollection)
        .doc(user.uid)
        .set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    var doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .get();

    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  Stream<UserModel?> streamUser(String uid) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  Future<void> linkPatient(String caregiverId, String patientId) async {
    await _db.collection(AppConstants.usersCollection).doc(caregiverId).update({
      'linkedPatientIds': FieldValue.arrayUnion([patientId])
    });

    await _db.collection(AppConstants.usersCollection).doc(patientId).update({
      'linkedCaregiverId': caregiverId,
    });
  }

  // ───────────────── FALL ALERTS ─────────────────

  Future<void> reportFall(FallAlertModel alert) async {
    await _db.collection(AppConstants.alertsCollection).add({
      'patientId': alert.patientId,
      'latitude': alert.latitude,
      'longitude': alert.longitude,
      'timestamp': FieldValue.serverTimestamp(),
      'isResolved': false,
    });
  }

  Stream<List<FallAlertModel>> getAlertsForPatient(String patientId) {
    return _db
        .collection(AppConstants.alertsCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FallAlertModel.fromMap(data);
      }).toList();
    });
  }

  // ───────────────── PUSH SUPPORT ─────────────────

  Stream<List<FallAlertModel>> alertStream() {
    return _db
        .collection(AppConstants.alertsCollection)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return FallAlertModel.fromMap(data);
      }).toList();
    });
  }
}
