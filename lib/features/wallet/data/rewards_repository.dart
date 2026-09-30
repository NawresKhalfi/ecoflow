import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/points_rules.dart';
import '../domain/rewards.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

/// Catalogue (`partners`, `rewards`) et coupons (`redemptions`) — US-072 à 074.
class RewardsRepository {
  RewardsRepository(this._db);
  final FirebaseFirestore _db;

  Redemption _redemption(DocumentSnapshot<Map<String, dynamic>> d) => Redemption.fromMap(
    d.id,
    d.data()!,
    createdAt: _date(d.data()!['createdAt']),
    usedAt: _date(d.data()!['usedAt']),
  );

  Stream<List<Partner>> watchPartners() => _db
      .collection('partners')
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) Partner.fromMap(d.id, d.data())]
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  Stream<List<Reward>> watchRewards() => _db
      .collection('rewards')
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) Reward.fromMap(d.id, d.data())]
              ..sort((a, b) => a.cost.compareTo(b.cost)),
      );

  Future<void> savePartner(Partner p) => p.id.isEmpty
      ? _db.collection('partners').add(p.toMap())
      : _db.collection('partners').doc(p.id).set(p.toMap());

  Future<void> saveReward(Reward r) => r.id.isEmpty
      ? _db.collection('rewards').add(r.toMap())
      : _db.collection('rewards').doc(r.id).set(r.toMap());

  Stream<List<Redemption>> watchMine(String uid) => _db
      .collection('redemptions')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => s.docs.map(_redemption).toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(3000)).compareTo(a.createdAt ?? DateTime(3000)),
          ),
      );

  /// Recherche d'un coupon par son code (validation chez le partenaire).
  Future<Redemption?> findByCode(String input) async {
    final raw = normalizeCode(input);
    if (raw.length != 8) return null;
    final code = '${raw.substring(0, 4)}-${raw.substring(4)}';
    final q = await _db.collection('redemptions').where('code', isEqualTo: code).limit(1).get();
    return q.docs.isEmpty ? null : _redemption(q.docs.first);
  }

  Future<void> markUsed(String id) => _db.collection('redemptions').doc(id).update({
    'status': RedemptionStatus.used.name,
    'usedAt': FieldValue.serverTimestamp(),
  });
}

/// Règles de points : `config/points`, historique `config/points/history` (US-071).
class PointsRulesRepository {
  PointsRulesRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('config').doc('points');

  Stream<PointsRules> watch() => _doc.snapshots().map((s) => PointsRules.fromMap(s.data()));

  Stream<List<({PointsRules rules, DateTime? at})>> watchHistory() => _doc
      .collection('history')
      .orderBy('at', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs) (rules: PointsRules.fromMap(d.data()), at: _date(d.data()['at'])),
        ],
      );

  Future<void> publish(PointsRules r, String adminUid) async {
    final batch = _db.batch()
      ..set(_doc, {...r.toMap(), 'updatedAt': FieldValue.serverTimestamp()})
      ..set(_doc.collection('history').doc(), {
        ...r.toMap(),
        'at': FieldValue.serverTimestamp(),
        'by': adminUid,
      });
    await batch.commit();
  }
}
