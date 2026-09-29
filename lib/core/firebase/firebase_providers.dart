import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Points d'accès Firebase injectables (surchargés par des fakes en test).
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Horloge injectable pour les règles dépendant du temps (OTP, verrouillage…).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
