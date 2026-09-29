import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/address.dart';

/// Adresses enregistrées : `users/{uid}/addresses/{id}`.
abstract interface class AddressRepository {
  Stream<List<SavedAddress>> watch(String uid);
  Future<void> save(String uid, SavedAddress address);
  Future<void> delete(String uid, String addressId);
  Future<void> setDefault(String uid, String addressId);
}

class FirestoreAddressRepository implements AddressRepository {
  FirestoreAddressRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('addresses');

  @override
  Stream<List<SavedAddress>> watch(String uid) => _col(uid).snapshots().map(
    (s) => normalizeAddresses([for (final d in s.docs) SavedAddress.fromMap(d.id, d.data())]),
  );

  @override
  Future<void> save(String uid, SavedAddress a) async {
    final col = _col(uid);
    final existing = await col.get();
    // La première adresse devient automatiquement l'adresse par défaut.
    final makeDefault = a.isDefault || existing.docs.every((d) => d.id == a.id);
    final ref = a.id.isEmpty ? col.doc() : col.doc(a.id);
    final batch = _db.batch();
    if (makeDefault) {
      for (final d in existing.docs.where((d) => d.id != ref.id)) {
        batch.update(d.reference, {'isDefault': false});
      }
    }
    batch.set(ref, a.copyWith(id: ref.id, isDefault: makeDefault).toMap());
    await batch.commit();
  }

  @override
  Future<void> delete(String uid, String addressId) async {
    final col = _col(uid);
    final doc = await col.doc(addressId).get();
    await col.doc(addressId).delete();
    // Si l'adresse par défaut est supprimée, la suivante prend le relais.
    if (doc.data()?['isDefault'] == true) {
      final rest = await col.limit(1).get();
      if (rest.docs.isNotEmpty) await rest.docs.first.reference.update({'isDefault': true});
    }
  }

  @override
  Future<void> setDefault(String uid, String addressId) async {
    final existing = await _col(uid).get();
    final batch = _db.batch();
    for (final d in existing.docs) {
      batch.update(d.reference, {'isDefault': d.id == addressId});
    }
    await batch.commit();
  }
}
