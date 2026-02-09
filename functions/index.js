const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendFallNotification = functions.firestore
  .document("alerts/{alertId}")
  .onCreate(async (snap, context) => {

  const alert = snap.data();
  const patientId = alert.patientId;

  // 1. Get PATIENT document
  const patientDoc = await admin.firestore()
      .collection("users")
      .doc(patientId)
      .get();

  if (!patientDoc.exists) {
    console.log("Patient not found");
    return;
  }

  // ─────────────────────────────────────
  // YOUR STRUCTURE:
  // caregiver doc contains linkedPatientIds
  // so we must FIND caregivers who contain this patient
  // ─────────────────────────────────────

  const caregiversSnap = await admin.firestore()
    .collection("users")
    .where("role", "==", "caregiver")
    .where("linkedPatientIds", "array-contains", patientId)
    .get();

  let tokens = [];

  caregiversSnap.forEach(doc => {
    const data = doc.data();
    if (data.fcmToken) {
      tokens.push(data.fcmToken);
    }
  });

  if (tokens.length === 0) {
    console.log("No caregiver tokens found");
    return;
  }

  // 2. Build notification
  const message = {
    notification: {
      title: "🚨 FALL DETECTED",
      body: "Your patient needs help immediately!"
    },

    data: {
      patientId: patientId,
      lat: String(alert.latitude),
      lng: String(alert.longitude),
      alertId: context.params.alertId
    },

    tokens: tokens
  };

  // 3. SEND
  await admin.messaging().sendMulticast(message);

  console.log("Push sent to caregivers:", tokens.length);
});
