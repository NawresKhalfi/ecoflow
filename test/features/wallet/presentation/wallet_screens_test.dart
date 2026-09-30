import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/wallet/domain/rewards.dart';
import 'package:ecoflow/features/wallet/presentation/screens/coupons_screen.dart';
import 'package:ecoflow/features/wallet/presentation/screens/fraud_screen.dart';
import 'package:ecoflow/features/wallet/presentation/screens/points_rules_screen.dart';
import 'package:ecoflow/features/wallet/presentation/screens/rewards_admin_screen.dart';
import 'package:ecoflow/features/wallet/presentation/screens/rewards_screen.dart';
import 'package:ecoflow/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;

  Future<List<Override>> as(String uid, String role) async {
    db = FakeFirebaseFirestore();
    await db.doc('users/$uid').set({'displayName': uid, 'role': role, 'status': 'active'});
    return [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          initialUser: AuthUser(uid: uid, email: '$uid@x.tn', providerIds: const ['password']),
        ),
      ),
      firestoreProvider.overrideWithValue(db),
    ];
  }

  Future<void> pumpIt(WidgetTester t, Widget w, List<Override> o) async {
    await pumpRoutedScreen(t, w, overrides: o, size: const Size(420, 3200));
    await settle(t);
  }

  testWidgets('wallet: balance, level, held points, history (US-070, US-076)', (t) async {
    final o = await as('leila', 'citizen');
    await db.doc('wallets/leila').set({'earned': 320, 'spent': 80, 'held': 158, 'collections': 2});
    await db.doc('pointEntries/c_1').set({
      'uid': 'leila',
      'type': 'earn',
      'points': 240,
      'status': 'credited',
      'kg': 12.0,
      'createdAt': DateTime.now(),
    });
    await db.doc('pointEntries/r_1').set({
      'uid': 'leila',
      'type': 'redeem',
      'points': -80,
      'status': 'credited',
      'label': 'Café offert',
      'createdAt': DateTime.now(),
    });
    await pumpIt(t, const WalletScreen(), o);
    expect(find.text('240'), findsOneWidget, reason: 'balance = 320 − 80');
    expect(find.textContaining('158 en vérification'), findsOneWidget);
    expect(find.text('Niveau Pousse'), findsOneWidget);
    expect(find.text('Café offert'), findsOneWidget);
    expect(
      find.text('−80').evaluate().isNotEmpty || find.text('-80').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.textContaining('Badges 2/'), findsOneWidget);
  });

  testWidgets('rewards: redeem → coupon with QR (US-072, US-073)', (t) async {
    final o = await as('leila', 'citizen');
    await db.doc('wallets/leila').set({'earned': 100});
    await db
        .doc('rewards/r1')
        .set(
          const Reward(
            id: 'r1',
            partnerId: 'p',
            partnerName: 'Café Sousse',
            title: 'Café offert',
            cost: 80,
            stock: 3,
          ).toMap(),
        );
    await db
        .doc('rewards/r2')
        .set(
          const Reward(
            id: 'r2',
            partnerId: 'p',
            partnerName: 'Vélo Club',
            title: 'Vélo',
            cost: 900,
          ).toMap(),
        );
    await pumpIt(t, const RewardsScreen(), o);
    expect(find.text('Points insuffisants'), findsOneWidget);
    expect(find.text('3 restants'), findsOneWidget);
    await t.tap(find.text('Échanger').first);
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Échanger'));
    await settle(t);
    expect(find.text('route:/app/wallet/coupons'), findsOneWidget);
    final coupons = await db.collection('redemptions').get();
    expect(coupons.docs.single.data()['cost'], 80);
    expect((await db.doc('wallets/leila').get()).data()!['spent'], 80);

    await pumpIt(t, const CouponsScreen(), o);
    expect(find.text('Café offert'), findsOneWidget);
    expect(find.text(coupons.docs.single.data()['code'] as String), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('QR du coupon')), findsOneWidget);
  });

  testWidgets('admin: held earning credited (US-075)', (t) async {
    final o = await as('admin', 'admin');
    await db.doc('wallets/leila').set({'earned': 0, 'held': 158});
    await db.doc('pointEntries/c_9').set({
      'uid': 'leila',
      'type': 'earn',
      'points': 158,
      'status': 'held',
      'kg': 9.0,
      'flags': ['estimateGap'],
    });
    await pumpIt(t, const FraudScreen(), o);
    expect(find.textContaining('Écart avec l’estimation'), findsOneWidget);
    await t.tap(find.text('Créditer'));
    await settle(t);
    final w = (await db.doc('wallets/leila').get()).data()!;
    expect((w['earned'], w['held']), (158, 0));
    expect(find.textContaining('Aucun gain en attente'), findsOneWidget);
  });

  testWidgets('admin: points rules draft, simulation and publish (US-071)', (t) async {
    final o = await as('admin', 'admin');
    await pumpIt(t, const PointsRulesScreen(), o);
    // 5 × 1,5 + 3 × 1,2 + 1 × 2 = 13,1 kg pondérés × 10.
    expect(find.textContaining('131 pts'), findsOneWidget);
    final slider = find.byType(Slider).first;
    await t.drag(slider, const Offset(200, 0));
    await settle(t);
    expect(find.text('Brouillon'), findsOneWidget);
    await t.tap(find.text('Publier les paramètres'));
    await settle(t);
    final cfg = (await db.doc('config/points').get()).data()!;
    expect(cfg['pointsPerKg'] as num, greaterThan(10));
    expect((await db.collection('config/points/history').get()).docs, hasLength(1));
  });

  testWidgets('admin: partner, offer and coupon validation (US-074)', (t) async {
    final o = await as('admin', 'admin');
    await db.doc('partners/p1').set(const Partner(id: 'p1', name: 'Café Sousse').toMap());
    await db.doc('redemptions/x1').set({
      'uid': 'leila',
      'rewardId': 'r1',
      'rewardTitle': 'Café offert',
      'partnerName': 'Café Sousse',
      'cost': 80,
      'code': 'ABCD-EF23',
      'status': 'active',
    });
    await pumpIt(t, const RewardsAdminScreen(), o);
    expect(find.text('Café Sousse'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, 'abcdef23');
    await t.tap(find.text('Rechercher'));
    await settle(t);
    expect(find.text('Café offert'), findsOneWidget);
    await t.tap(find.text('Marquer comme utilisé'));
    await settle(t);
    expect((await db.doc('redemptions/x1').get()).data()!['status'], 'used');

    await t.tap(find.text('＋ Ajouter une offre'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'Intitulé'), 'Sac recyclé');
    await t.enterText(find.widgetWithText(TextFormField, 'Coût (points)'), '150');
    await t.tap(find.text('Enregistrer'));
    await settle(t);
    final rewards = await db.collection('rewards').get();
    expect(rewards.docs.single.data()['title'], 'Sac recyclé');
    expect(rewards.docs.single.data()['partnerName'], 'Café Sousse');
  });
}
