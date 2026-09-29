import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Développement local : `flutter run --dart-define=USE_FIREBASE_EMULATORS=true`
/// après `firebase emulators:start --only auth,firestore`. Ignoré en release.
const useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

Future<void> connectFirebaseEmulators() async {
  if (!kDebugMode || !useFirebaseEmulators) return;
  const host = String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: 'localhost');
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
}
