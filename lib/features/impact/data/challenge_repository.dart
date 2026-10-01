import 'package:cloud_firestore/cloud_firestore.dart';

import '../../admin/domain/admin.dart';
import '../../wallet/domain/wallet.dart';
import '../domain/challenge.dart';

DateTime? _date(Object? v) => v is Timestamp
    ? v.toDate()
    : v is DateTime
    ? v
    : null;

class ChallengeClosed implements Exception {
  const ChallengeClosed();
}

/// Défis communautaires (US-121). Chaque écriture citoyenne est un couple
/// participant + défi que les règles Firestore recoupent avec le wallet.
class ChallengeRepository {
  ChallengeRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _all => _db.collection('challenges');
  DocumentReference<Map<String, dynamic>> _participant(String cid, String uid) =>
      _all.doc(cid).collection('participants').doc(uid);
  DocumentReference<Map<String, dynamic>> _wallet(String uid) => _db.collection('wallets').doc(uid);

  Challenge _from(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Challenge.fromMap(
      d.id,
      m,
      startAt: _date(m['startAt']) ?? DateTime(2000),
      endAt: _date(m['endAt']) ?? DateTime(2000),
    );
  }

  Stream<List<Challenge>> watchChallenges() => _all
      .orderBy('endAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => [for (final d in s.docs) _from(d)]);

  Stream<Challenge?> watch(String id) =>
      _all.doc(id).snapshots().map((d) => d.exists ? _from(d) : null);

  Stream<List<Participant>> watchParticipants(String cid) => _all
      .doc(cid)
      .collection('participants')
      .orderBy('kg', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            Participant.fromMap(d.id, d.data(), joinedAt: _date(d.data()['joinedAt'])),
        ],
      );

  /// Ma participation à un défi, `null` si je n'y suis pas inscrit.
  Stream<Participant?> watchMe(String cid, String uid) => _participant(cid, uid).snapshots().map(
    (d) => d.exists
        ? Participant.fromMap(d.id, d.data()!, joinedAt: _date(d.data()!['joinedAt']))
        : null,
  );

  /// Inscription : la base est le compteur de kilos actuel du wallet.
  Future<void> join(String cid, String uid, {required String name, String? zoneId}) =>
      _db.runTransaction((tx) async {
        final w = await tx.get(_wallet(uid));
        final base = (w.data()?['kg'] as num?)?.toDouble() ?? 0;
        tx.set(_participant(cid, uid), {
          'uid': uid,
          'name': name,
          'zoneId': zoneId,
          'baseKg': base,
          'kg': 0.0,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        tx.update(_all.doc(cid), {'participants': FieldValue.increment(1), 'lastParticipant': uid});
      });

  /// Reporte les kilos recyclés depuis l'inscription ; renvoie l'écart.
  Future<double> sync(String cid, String uid) => _db.runTransaction((tx) async {
    final w = await tx.get(_wallet(uid));
    final p = await tx.get(_participant(cid, uid));
    if (!p.exists) return 0;
    final me = Participant.fromMap(uid, p.data()!);
    final kg = syncedKg((w.data()?['kg'] as num?)?.toDouble() ?? 0, me.baseKg);
    if (kg <= me.kg) return 0;
    tx.update(p.reference, {'kg': kg});
    tx.update(_all.doc(cid), {'totalKg': FieldValue.increment(kg - me.kg), 'lastParticipant': uid});
    return kg - me.kg;
  });

  /// Récompense d'un défi réussi : un mouvement `ch_{défi}_{uid}` crédité.
  Future<void> claim(Challenge c, String uid) => _db.runTransaction((tx) async {
    final w = Wallet.fromMap((await tx.get(_wallet(uid))).data());
    final id = challengeEntryId(c.id, uid);
    tx.set(_db.collection('pointEntries').doc(id), {
      ...LedgerEntry(
        id: id,
        uid: uid,
        type: EntryType.challenge,
        points: c.rewardPoints,
        challengeId: c.id,
        label: c.title,
      ).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    tx.update(_wallet(uid), {'earned': w.earned + c.rewardPoints, 'lastEntryId': id});
  });

  Future<void> create(({String uid, String name}) actor, Challenge c) {
    final ref = _all.doc();
    return (_db.batch()
          ..set(ref, {
            ...c.toCreateMap(),
            'createdBy': actor.uid,
            'createdAt': FieldValue.serverTimestamp(),
          })
          ..set(_audit(), _auditData(actor, AuditAction.challengeCreate, ref.id, c.title)))
        .commit();
  }

  Future<void> delete(({String uid, String name}) actor, Challenge c) =>
      (_db.batch()
            ..delete(_all.doc(c.id))
            ..set(_audit(), _auditData(actor, AuditAction.challengeDelete, c.id, c.title)))
          .commit();

  DocumentReference<Map<String, dynamic>> _audit() => _db.collection('auditLog').doc();
  Map<String, dynamic> _auditData(
    ({String uid, String name}) actor,
    String action,
    String id,
    String details,
  ) => {
    'actorUid': actor.uid,
    'actorName': actor.name,
    'action': action,
    'targetType': 'challenge',
    'targetId': id,
    'details': details,
    'at': FieldValue.serverTimestamp(),
  };
}
