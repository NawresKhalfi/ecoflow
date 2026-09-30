import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/points_rules.dart';
import '../domain/rewards.dart';
import '../domain/wallet.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

class ReferralCodeUnknown implements Exception {
  const ReferralCodeUnknown();
}

class ReferralNotAllowed implements Exception {
  const ReferralNotAllowed();
}

class RedeemRefused implements Exception {
  const RedeemRefused(this.reason);
  final RedeemRefusal reason;
}

/// Recycle Wallet : `wallets/{uid}`, `pointEntries/{id}`, `referralCodes/{code}`.
/// Chaque variation du portefeuille s'accompagne d'un mouvement dans le même
/// batch ; les règles Firestore recalculent les gains à partir de la pesée.
class WalletRepository {
  WalletRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _wallet(String uid) => _db.collection('wallets').doc(uid);
  DocumentReference<Map<String, dynamic>> _entry(String id) =>
      _db.collection('pointEntries').doc(id);

  Wallet _walletFrom(Map<String, dynamic>? m) =>
      Wallet.fromMap(m, lastEarnAt: _date(m?['lastEarnAt']));
  LedgerEntry _entryFrom(DocumentSnapshot<Map<String, dynamic>> d) =>
      LedgerEntry.fromMap(d.id, d.data()!, at: _date(d.data()!['createdAt']));

  Stream<Wallet> watch(String uid) => _wallet(uid).snapshots().map((s) => _walletFrom(s.data()));

  Stream<List<LedgerEntry>> watchEntries(String uid) => _db
      .collection('pointEntries')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(_entryFrom).toList()
              ..sort((a, b) => (b.at ?? DateTime(3000)).compareTo(a.at ?? DateTime(3000))),
      );

  /// Crédite une collecte terminée et pesée (US-069). Idempotent : un seul
  /// mouvement `c_{collecte}`. À la première collecte d'un filleul, le
  /// parrain reçoit son bonus dans la même transaction (US-077).
  Future<LedgerEntry?> awardCollection({
    required String uid,
    required String collectionId,
    required String estimateCode,
    required PointsRules rules,
    required DateTime now,
  }) => _db.runTransaction((tx) async {
    final entryRef = _entry(LedgerEntry.earnId(collectionId));
    if ((await tx.get(entryRef)).exists) return null;
    final est = (await tx.get(_db.collection('estimates').doc(estimateCode))).data();
    if (est == null || est['status'] != 'weighed') return null;
    final w = _walletFrom((await tx.get(_wallet(uid))).data());
    final referrer = w.collections == 0 ? w.referredBy : null;
    final actualKg = {
      for (final e in (est['actualKg'] as Map? ?? const {}).entries)
        '${e.key}': (e.value as num).toDouble(),
    };
    final total = (est['actualTotalKg'] as num?)?.toDouble() ?? 0;
    final dayCount = nextDayCount(w.lastEarnAt, w.dayCount, now);
    final award = computeAward(
      rules,
      actualKg: actualKg,
      actualTotalKg: total,
      estimatedKg: (est['totalKg'] as num?)?.toDouble() ?? 0,
      firstCollection: w.collections == 0,
      dayCount: dayCount,
    );
    final entry = LedgerEntry(
      id: entryRef.id,
      uid: uid,
      type: EntryType.earn,
      points: award.total,
      status: award.held ? EntryStatus.held : EntryStatus.credited,
      collectionId: collectionId,
      kg: total,
      byCategory: actualKg,
      flags: award.flags,
    );
    tx.set(entryRef, {...entry.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    tx.set(_wallet(uid), {
      ...w
          .copyWith(
            earned: w.earned + (award.held ? 0 : award.total),
            held: w.held + (award.held ? award.total : 0),
            collections: w.collections + 1,
            kg: w.kg + total,
            dayCount: dayCount,
            lastEntryId: entryRef.id,
          )
          .toMap(),
      'lastEarnAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (referrer != null) {
      final refRef = _entry(LedgerEntry.referralId(uid));
      tx.set(refRef, {
        ...LedgerEntry(
          id: refRef.id,
          uid: referrer,
          type: EntryType.referral,
          points: rules.referralBonus,
        ).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Le filleul ne lit pas le portefeuille du parrain (qui existe : il
      // porte le code de parrainage) : incrément.
      tx.update(_wallet(referrer), {
        'earned': FieldValue.increment(rules.referralBonus),
        'lastEntryId': refRef.id,
      });
    }
    return entry;
  });

  /// Échange de points contre un coupon (US-073) : coupon, dépense et stock
  /// dans la même transaction.
  Future<String> redeem(String uid, Reward reward) => _db.runTransaction((tx) async {
    final rewardSnap = await tx.get(_db.collection('rewards').doc(reward.id));
    final fresh = Reward.fromMap(reward.id, rewardSnap.data() ?? const {});
    final w = _walletFrom((await tx.get(_wallet(uid))).data());
    final refusal = redeemRefusal(fresh, w.balance, frozen: w.frozen);
    if (!rewardSnap.exists || refusal != null) {
      throw RedeemRefused(refusal ?? RedeemRefusal.unavailable);
    }
    final ref = _db.collection('redemptions').doc();
    final entryRef = _entry(LedgerEntry.redeemId(ref.id));
    tx.set(ref, {
      'uid': uid,
      'rewardId': fresh.id,
      'rewardTitle': fresh.title,
      'partnerName': fresh.partnerName,
      'cost': fresh.cost,
      'code': randomCode(),
      'status': RedemptionStatus.active.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    tx.set(entryRef, {
      ...LedgerEntry(
        id: entryRef.id,
        uid: uid,
        type: EntryType.redeem,
        points: -fresh.cost,
        redemptionId: ref.id,
        label: fresh.title,
      ).toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    tx.update(_wallet(uid), {
      'spent': w.spent + fresh.cost,
      'lastEntryId': entryRef.id,
      'lastRedemptionId': ref.id,
    });
    if (fresh.stock != null) tx.update(rewardSnap.reference, {'stock': fresh.stock! - 1});
    return ref.id;
  });

  /// Déduit les points arrivés à échéance (US-078). Le montant est
  /// recalculé sur le wallet lu dans la transaction : idempotent.
  Future<int> expireDue(String uid, List<LedgerEntry> entries, int expiryMonths, DateTime now) =>
      _db.runTransaction((tx) async {
        final w = _walletFrom((await tx.get(_wallet(uid))).data());
        final amount = duePointsToExpire(entries, w, expiryMonths, now);
        if (amount == 0) return 0;
        final entryRef = _db.collection('pointEntries').doc();
        tx.set(entryRef, {
          ...LedgerEntry(
            id: entryRef.id,
            uid: uid,
            type: EntryType.expire,
            points: -amount,
          ).toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.update(_wallet(uid), {'expired': w.expired + amount, 'lastEntryId': entryRef.id});
        return amount;
      });

  /// Code de parrainage personnel, créé à la première demande (US-077).
  Future<String> ensureReferralCode(String uid) async {
    final existing = (await _wallet(uid).get()).data()?['referralCode'] as String?;
    if (existing != null) return existing;
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = randomCode(length: 6);
      final codeRef = _db.collection('referralCodes').doc(code);
      if ((await codeRef.get()).exists) continue;
      final batch = _db.batch()
        ..set(codeRef, {'uid': uid})
        ..set(_wallet(uid), {'referralCode': code}, SetOptions(merge: true));
      await batch.commit();
      return code;
    }
    throw StateError('referral code');
  }

  /// Rattache le citoyen à un parrain, avant sa première collecte.
  Future<void> applyReferralCode(String uid, String input) async {
    final code = normalizeCode(input);
    if (code.isEmpty) throw const ReferralCodeUnknown();
    final owner = (await _db.collection('referralCodes').doc(code).get()).data()?['uid'] as String?;
    if (owner == null) throw const ReferralCodeUnknown();
    final w = _walletFrom((await _wallet(uid).get()).data());
    if (owner == uid || w.referredBy != null || w.collections > 0) {
      throw const ReferralNotAllowed();
    }
    await _wallet(uid).set({'referredBy': owner}, SetOptions(merge: true));
  }

  // --- Administration (US-075) ---------------------------------------------

  Stream<List<LedgerEntry>> watchHeld() => _db
      .collection('pointEntries')
      .where('status', isEqualTo: EntryStatus.held.name)
      .snapshots()
      .map((s) => s.docs.map(_entryFrom).toList());

  /// Valide (crédite) ou rejette des points mis en attente.
  Future<void> review(LedgerEntry e, {required bool approve, required String adminUid}) =>
      _db.runTransaction((tx) async {
        final w = _walletFrom((await tx.get(_wallet(e.uid))).data());
        tx.update(_entry(e.id), {
          'status': (approve ? EntryStatus.credited : EntryStatus.rejected).name,
          'reviewedBy': adminUid,
          'reviewedAt': FieldValue.serverTimestamp(),
        });
        tx.update(_wallet(e.uid), {
          'held': w.held - e.points,
          if (approve) 'earned': w.earned + e.points,
        });
      });

  Future<void> setFrozen(String uid, {required bool frozen, String? reason}) => _wallet(
    uid,
  ).set({'frozen': frozen, 'frozenReason': frozen ? reason : null}, SetOptions(merge: true));
}
