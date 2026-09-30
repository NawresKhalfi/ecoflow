import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/wallet/application/wallet_providers.dart';
import 'package:ecoflow/features/wallet/data/wallet_repository.dart';
import 'package:ecoflow/features/wallet/domain/points_rules.dart';
import 'package:ecoflow/features/wallet/domain/rewards.dart';
import 'package:ecoflow/features/wallet/domain/wallet.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late WalletRepository repo;
  // Horloge réelle : le jour du dernier gain vient de l'horodatage serveur.
  final now = DateTime.now();

  Future<void> weighed(String code, Map<String, double> kg, {double estimated = 2}) =>
      db.doc('estimates/$code').set({
        'citizenUid': 'leila',
        'status': 'weighed',
        'actualKg': kg,
        'actualTotalKg': kg.values.fold(0.0, (s, v) => s + v),
        'totalKg': estimated,
      });

  Future<LedgerEntry?> award(String uid, String cid, String code) => repo.awardCollection(
    uid: uid,
    collectionId: cid,
    estimateCode: code,
    rules: const PointsRules(),
    now: now,
  );

  Future<Wallet> wallet(String uid) async =>
      Wallet.fromMap((await db.doc('wallets/$uid').get()).data());

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = WalletRepository(db);
  });

  test('a weighed pickup is credited once, with the first-pickup bonus (US-069)', () async {
    await weighed('E1', {'can': 2.5});
    final e = await award('leila', 'c1', 'E1');
    expect(e!.points, 100);
    expect(e.id, 'c_c1');
    expect(await award('leila', 'c1', 'E1'), isNull, reason: 'idempotent');
    await weighed('E2', {'paper': 3});
    expect((await award('leila', 'c2', 'E2'))!.points, 30);
    final w = await wallet('leila');
    expect((w.earned, w.collections, w.kg, w.dayCount), (130, 2, 5.5, 2));
    expect(w.lastEntryId, 'c_c2');
  });

  test('not yet weighed: nothing is credited', () async {
    await db.doc('estimates/E1').set({'citizenUid': 'leila', 'status': 'estimated'});
    expect(await award('leila', 'c1', 'E1'), isNull);
    expect((await db.collection('pointEntries').get()).docs, isEmpty);
  });

  test('anomalous weighing is held, then approved by the admin (US-075)', () async {
    await weighed('E1', {'glass': 9});
    final e = await award('leila', 'c1', 'E1');
    expect(e!.status, EntryStatus.held);
    expect(e.flags, [FraudFlag.estimateGap]);
    var w = await wallet('leila');
    expect((w.earned, w.held), (0, 158));
    final stored = LedgerEntry.fromMap(e.id, (await db.doc('pointEntries/${e.id}').get()).data()!);
    await repo.review(stored, approve: true, adminUid: 'admin');
    w = await wallet('leila');
    expect((w.earned, w.held), (158, 0));
    expect((await db.doc('pointEntries/${e.id}').get()).data()!['status'], 'credited');
  });

  test('referral: code, link, bonus to the referrer on the first pickup (US-077)', () async {
    final code = await repo.ensureReferralCode('leila');
    expect(await repo.ensureReferralCode('leila'), code, reason: 'stable');
    await expectLater(repo.applyReferralCode('leila', code), throwsA(isA<ReferralNotAllowed>()));
    await expectLater(
      repo.applyReferralCode('sami', 'ZZZZZZ'),
      throwsA(isA<ReferralCodeUnknown>()),
    );
    await repo.applyReferralCode('sami', code.toLowerCase());
    await weighed('E1', {'can': 1});
    await award('sami', 'c1', 'E1');
    expect((await wallet('leila')).earned, 100);
    expect((await db.doc('pointEntries/ref_sami').get()).data()!['uid'], 'leila');
    await weighed('E2', {'can': 1});
    await award('sami', 'c2', 'E2');
    expect((await wallet('leila')).earned, 100, reason: 'only once');
  });

  test('redeem: coupon, spending and stock in one transaction (US-073)', () async {
    await weighed('E1', {'can': 2.5});
    await award('leila', 'c1', 'E1');
    const reward = Reward(
      id: 'r1',
      partnerId: 'p',
      partnerName: 'Monoprix',
      title: '-10 %',
      cost: 80,
      stock: 2,
    );
    await db.doc('rewards/r1').set(reward.toMap());
    final rid = await repo.redeem('leila', reward);
    final coupon = (await db.doc('redemptions/$rid').get()).data()!;
    expect(coupon['cost'], 80);
    expect(coupon['code'], matches(RegExp(r'^[A-Z2-9]{4}-[A-Z2-9]{4}$')));
    expect((await db.doc('rewards/r1').get()).data()!['stock'], 1);
    final w = await wallet('leila');
    expect((w.balance, w.lastRedemptionId), (20, rid));
    await expectLater(
      repo.redeem('leila', reward),
      throwsA(isA<RedeemRefused>().having((e) => e.reason, 'reason', RedeemRefusal.insufficient)),
    );
    await repo.setFrozen('leila', frozen: true, reason: 'x');
    await db
        .doc('rewards/r2')
        .set(const Reward(id: 'r2', partnerId: 'p', partnerName: 'P', title: 'x', cost: 1).toMap());
    await expectLater(
      repo.redeem(
        'leila',
        const Reward(id: 'r2', partnerId: 'p', partnerName: 'P', title: 'x', cost: 1),
      ),
      throwsA(isA<RedeemRefused>().having((e) => e.reason, 'reason', RedeemRefusal.frozen)),
    );
  });

  test('wallet sync credits missed pickups and expires old points (US-078)', () async {
    await db.doc('collections/c1').set({
      'citizenUid': 'leila',
      'estimateCode': 'E1',
      'status': 'completed',
      'slotId': '2026-10-01_10',
      'place': {
        'point': {'lat': 35.8, 'lng': 10.6},
        'address': 'A',
        'zoneId': 'sousse',
      },
    });
    await weighed('E1', {'can': 2.5});
    // Gain vieux de 13 mois, non dépensé.
    await db.doc('pointEntries/old').set({
      'uid': 'leila',
      'type': 'earn',
      'points': 40,
      'status': 'credited',
      'createdAt': now.subtract(const Duration(days: 400)),
    });
    await db.doc('wallets/leila').set({'earned': 40, 'collections': 1});
    final c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: const AuthUser(uid: 'leila', email: 'l@x.tn', providerIds: ['password']),
          ),
        ),
        firestoreProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    c.listen(walletSyncProvider, (_, _) {});
    await pumpEventQueue();
    expect(c.read(currentUidProvider), 'leila');
    await c.read(walletSyncProvider.future);
    await pumpEventQueue();
    final w = await wallet('leila');
    // 2,5 kg de canettes = 50 (pas de bonus : déjà une collecte), 40 expirés.
    expect((w.earned, w.expired, w.balance), (90, 40, 50));
  });
}
