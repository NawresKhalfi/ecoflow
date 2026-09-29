import 'package:cloud_firestore/cloud_firestore.dart';

/// Délai légal maximal d'anonymisation annoncé à l'utilisateur (US-010).
const anonymizationDelay = Duration(days: 30);

/// Anonymise les données personnelles avant suppression du compte Auth.
/// L'historique financier (wallet, revenus – epics suivants) est conservé,
/// rattaché à l'identifiant anonymisé.
abstract interface class AccountDeletionRepository {
  Future<void> anonymize(String uid, DateTime now);
}

class FirestoreAccountDeletionRepository implements AccountDeletionRepository {
  FirestoreAccountDeletionRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> anonymize(String uid, DateTime now) async {
    final user = _db.collection('users').doc(uid);
    final batch = _db.batch();
    for (final sub in ['addresses', 'documents', 'documentFiles']) {
      final docs = await user.collection(sub).get();
      for (final d in docs.docs) {
        batch.delete(d.reference);
      }
    }
    final company = await _db.collection('companies').doc(uid).get();
    if (company.exists) batch.update(company.reference, {'contactPhone': null});
    batch.update(user, {
      'displayName': 'Utilisateur supprimé',
      'email': null,
      'phoneNumber': null,
      'status': 'deleted',
      'deletedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('deletionRequests').doc(uid), {
      'requestedAt': FieldValue.serverTimestamp(),
      'purgeBefore': Timestamp.fromDate(now.add(anonymizationDelay)),
    });
    await batch.commit();
  }
}
