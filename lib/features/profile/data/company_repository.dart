import 'package:cloud_firestore/cloud_firestore.dart';

import '../../auth/domain/verification_status.dart';
import '../domain/company_profile.dart';

/// Profil entreprise : `companies/{uid}` (US-007).
abstract interface class CompanyRepository {
  Stream<CompanyProfile?> watch(String uid);

  /// Enregistre le profil et le soumet à la validation de l'administrateur.
  Future<void> submit(String uid, CompanyProfile profile);
}

class FirestoreCompanyRepository implements CompanyRepository {
  FirestoreCompanyRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<CompanyProfile?> watch(String uid) => _db
      .collection('companies')
      .doc(uid)
      .snapshots()
      .map((s) => s.data() == null ? null : CompanyProfile.fromMap(s.data()!));

  @override
  Future<void> submit(String uid, CompanyProfile p) async {
    final batch = _db.batch();
    batch.set(_db.collection('companies').doc(uid), {
      ...p.toMap(),
      'ownerUid': uid,
      'status': VerificationStatus.pending.name,
      'rejectionReason': null,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('users').doc(uid), {
      'verificationStatus': VerificationStatus.pending.name,
      'submittedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
