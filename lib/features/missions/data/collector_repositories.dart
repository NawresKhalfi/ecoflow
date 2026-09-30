import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;

import '../domain/deposit.dart';
import '../domain/earnings.dart';
import '../domain/vehicle.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

/// Revenus (`earnings/{missionId}`) et retraits (`payouts/{id}`) — US-050 à 052.
abstract interface class EarningsRepository {
  /// Crédite une mission terminée (idempotent : un revenu par mission).
  Future<void> ensureEarning({
    required String missionId,
    required String uid,
    required double amountDt,
    required double kg,
  });
  Stream<List<Earning>> watchEarnings(String uid);
  Stream<List<Payout>> watchPayouts(String uid);
  Future<void> requestPayout(String uid, double amountDt, PayoutMethod method);
}

class FirestoreEarningsRepository implements EarningsRepository {
  FirestoreEarningsRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _balance(String uid) =>
      _db.collection('collectorBalances').doc(uid);

  static double _num(Map<String, dynamic>? m, String k) => (m?[k] as num?)?.toDouble() ?? 0;

  /// Le solde (gagné / retiré) est mis à jour dans la même transaction que
  /// chaque revenu ou retrait : les règles en vérifient la cohérence et
  /// interdisent de retirer plus que le total gagné.
  @override
  Future<void> ensureEarning({
    required String missionId,
    required String uid,
    required double amountDt,
    required double kg,
  }) => _db.runTransaction((tx) async {
    final ref = _db.collection('earnings').doc(missionId);
    if ((await tx.get(ref)).exists) return;
    final bal = (await tx.get(_balance(uid))).data();
    tx.set(ref, {
      'collectorUid': uid,
      'amountDt': amountDt,
      'kg': kg,
      'createdAt': FieldValue.serverTimestamp(),
    });
    tx.set(_balance(uid), {
      'earnedDt': _num(bal, 'earnedDt') + amountDt,
      'withdrawnDt': _num(bal, 'withdrawnDt'),
      'lastEarningId': missionId,
      'lastPayoutId': bal?['lastPayoutId'],
    });
  });

  @override
  Stream<List<Earning>> watchEarnings(String uid) => _db
      .collection('earnings')
      .where('collectorUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            Earning(
              missionId: d.id,
              amountDt: (d.data()['amountDt'] as num?)?.toDouble() ?? 0,
              kg: (d.data()['kg'] as num?)?.toDouble() ?? 0,
              at: _date(d.data()['createdAt']) ?? DateTime.now(),
            ),
        ]..sort((a, b) => b.at.compareTo(a.at)),
      );

  @override
  Stream<List<Payout>> watchPayouts(String uid) => _db
      .collection('payouts')
      .where('collectorUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            [
              for (final d in s.docs)
                Payout(
                  id: d.id,
                  amountDt: (d.data()['amountDt'] as num?)?.toDouble() ?? 0,
                  method:
                      PayoutMethod.values.where((m) => m.name == d.data()['method']).firstOrNull ??
                      PayoutMethod.bankTransfer,
                  status:
                      PayoutStatus.values.where((m) => m.name == d.data()['status']).firstOrNull ??
                      PayoutStatus.requested,
                  requestedAt: _date(d.data()['requestedAt']),
                ),
            ]..sort(
              (a, b) =>
                  (b.requestedAt ?? DateTime(3000)).compareTo(a.requestedAt ?? DateTime(3000)),
            ),
      );

  @override
  Future<void> requestPayout(String uid, double amountDt, PayoutMethod method) =>
      _db.runTransaction((tx) async {
        final ref = _db.collection('payouts').doc();
        final bal = (await tx.get(_balance(uid))).data();
        final withdrawn = _num(bal, 'withdrawnDt') + amountDt;
        if (withdrawn > _num(bal, 'earnedDt') + 1e-9) throw StateError('insufficient balance');
        tx.set(ref, {
          'collectorUid': uid,
          'amountDt': amountDt,
          'method': method.name,
          'status': PayoutStatus.requested.name,
          'requestedAt': FieldValue.serverTimestamp(),
        });
        tx.set(_balance(uid), {
          'earnedDt': _num(bal, 'earnedDt'),
          'withdrawnDt': withdrawn,
          'lastEarningId': bal?['lastEarningId'],
          'lastPayoutId': ref.id,
        });
      });
}

/// Véhicule du collecteur : champ `vehicle` de `users/{uid}` (US-054).
abstract interface class VehicleRepository {
  Stream<Vehicle?> watch(String uid);
  Future<void> save(String uid, Vehicle v);
}

class FirestoreVehicleRepository implements VehicleRepository {
  FirestoreVehicleRepository(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<Vehicle?> watch(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) => Vehicle.fromMap(s.data()?['vehicle']));

  @override
  Future<void> save(String uid, Vehicle v) async {
    final batch = _db.batch()
      ..update(_db.collection('users').doc(uid), {'vehicle': v.toMap()})
      // La recherche automatique utilise la capacité déclarée.
      ..set(_db.collection('collectorPresence').doc(uid), {
        'capacityKg': v.capacityKg,
      }, SetOptions(merge: true));
    await batch.commit();
  }
}

/// Recycleur validé pouvant recevoir un dépôt.
typedef Recycler = ({String uid, String name, String city});

/// Dépôts de tournée chez un recycleur : `deposits/{id}` (US-055).
abstract interface class DepositRepository {
  Future<List<Recycler>> approvedRecyclers();
  Future<String> create(Deposit d);
  Stream<List<Deposit>> watchByCollector(String uid);
  Stream<List<Deposit>> watchIncoming(String recyclerUid);

  /// Confirmation (ou refus) par le recycleur destinataire.
  Future<void> review(String id, {required bool confirmed, String note});
}

class FirestoreDepositRepository implements DepositRepository {
  FirestoreDepositRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('deposits');

  Deposit _from(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Deposit(
      id: d.id,
      collectorUid: m['collectorUid'] as String? ?? '',
      recyclerUid: m['recyclerUid'] as String? ?? '',
      recyclerName: m['recyclerName'] as String? ?? '',
      missionIds: (m['missionIds'] as List? ?? const []).cast<String>(),
      byCategoryKg: {
        for (final e in (m['byCategoryKg'] as Map? ?? const {}).entries)
          '${e.key}': (e.value as num).toDouble(),
      },
      status:
          DepositStatus.values.where((s) => s.name == m['status']).firstOrNull ??
          DepositStatus.pending,
      createdAt: _date(m['createdAt']),
      note: m['note'] as String? ?? '',
    );
  }

  @override
  Future<List<Recycler>> approvedRecyclers() async {
    final q = await _db.collection('companies').where('status', isEqualTo: 'approved').get();
    return [
      for (final d in q.docs)
        (
          uid: d.id,
          name: d.data()['legalName'] as String? ?? '',
          city: d.data()['city'] as String? ?? '',
        ),
    ];
  }

  @override
  Future<String> create(Deposit d) async {
    final ref = _col.doc();
    final batch = _db.batch()
      ..set(ref, {
        'collectorUid': d.collectorUid,
        'recyclerUid': d.recyclerUid,
        'recyclerName': d.recyclerName,
        'missionIds': d.missionIds,
        'byCategoryKg': d.byCategoryKg,
        'totalKg': d.totalKg,
        'status': DepositStatus.pending.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    for (final id in d.missionIds) {
      batch.update(_db.collection('collections').doc(id), {'depositId': ref.id});
    }
    await batch.commit();
    return ref.id;
  }

  @override
  Stream<List<Deposit>> watchByCollector(String uid) =>
      _col.where('collectorUid', isEqualTo: uid).snapshots().map((s) => s.docs.map(_from).toList());

  @override
  Stream<List<Deposit>> watchIncoming(String recyclerUid) => _col
      .where('recyclerUid', isEqualTo: recyclerUid)
      .snapshots()
      .map((s) => s.docs.map(_from).toList());

  @override
  Future<void> review(String id, {required bool confirmed, String note = ''}) =>
      _col.doc(id).update({
        'status': (confirmed ? DepositStatus.confirmed : DepositStatus.rejected).name,
        'note': note.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });
}
