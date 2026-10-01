import 'dart:io';

import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/impact/application/impact_providers.dart';
import 'package:ecoflow/features/impact/presentation/screens/challenge_detail_screen.dart';
import 'package:ecoflow/features/impact/presentation/screens/challenges_screen.dart';
import 'package:ecoflow/features/impact/presentation/screens/impact_screen.dart';
import 'package:ecoflow/features/impact/presentation/screens/tips_screen.dart';
import 'package:ecoflow/features/recycler/application/recycler_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

final now = DateTime(2026, 10, 15, 10);

void main() {
  late FakeFirebaseFirestore db;
  final shared = <(String, String)>[];
  late Directory tmp;

  setUpAll(() async => tmp = await Directory.systemTemp.createTemp('impact'));
  tearDownAll(() => tmp.delete(recursive: true));

  Future<List<Override>> as(String uid, String role) async {
    await db.doc('users/$uid').set({
      'displayName': uid == 'leila' ? 'Leila Trabelsi' : 'Sarra Admin',
      'role': role,
      'status': 'active',
    });
    return [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          initialUser: AuthUser(
            uid: uid,
            phoneNumber: '+21622000003',
            providerIds: const ['phone'],
          ),
        ),
      ),
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      exportDirectoryProvider.overrideWithValue(() async => tmp),
      imageSharerProvider.overrideWithValue((path, text) async => shared.add((path, text))),
    ];
  }

  Future<void> pumpIt(WidgetTester t, Widget w, List<Override> o) async {
    await pumpRoutedScreen(t, w, overrides: o, size: const Size(420, 3200));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
    await settle(t);
  }

  Future<void> weighed(String code, DateTime at, Map<String, double> kg) =>
      db.doc('estimates/$code').set({
        'citizenUid': 'leila',
        'status': 'weighed',
        'lines': [
          for (final e in kg.entries)
            {'category': e.key, 'count': 0, 'kg': e.value, 'price': .5, 'method': 'manual'},
        ],
        'confidence': .9,
        'priceScaleId': 's1',
        'actualKg': kg,
        'createdAt': at,
        'weighedAt': at,
      });

  setUp(() {
    db = FakeFirebaseFirestore();
    shared.clear();
  });

  testWidgets('dashboard, CO₂, equivalents and share card (US-118, US-119, US-122)', (t) async {
    final o = await as('leila', 'citizen');
    await weighed('A', DateTime(2026, 10, 3), {'pet_bottle': 6, 'can': 2});
    await weighed('B', DateTime(2026, 9, 12), {'cardboard': 4});
    await pumpIt(t, const ImpactScreen(), o);
    expect(find.text('12,00'), findsOneWidget, reason: 'total kg');
    expect(find.text('+100 % vs mois dernier'), findsOneWidget);
    expect(find.text('30,60 kg CO₂e'), findsOneWidget, reason: '6×1,5 + 2×9 + 4×0,9');
    expect(find.text('159 km en voiture évités'), findsOneWidget);
    expect(find.textContaining('recharges de smartphone'), findsOneWidget);

    await t.ensureVisible(find.text('Partager mon impact'));
    await t.tap(find.text('Partager mon impact'));
    await settle(t);
    expect(find.text('Leila a recyclé'), findsOneWidget);
    await t.runAsync(() async {
      await t.tap(find.text('Partager'));
      for (var i = 0; i < 30 && shared.isEmpty; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        await t.pump();
      }
    });
    expect(shared, hasLength(1));
    expect(File(shared.single.$1).lengthSync(), greaterThan(1000), reason: 'PNG rendered');
    expect(shared.single.$2, contains('12,00 kg'));
  });

  testWidgets('empty impact invites to scan', (t) async {
    final o = await as('leila', 'citizen');
    await pumpIt(t, const ImpactScreen(), o);
    expect(find.text('🌱 Ton impact commence ici'), findsOneWidget);
    expect(find.text('Partager mon impact'), findsNothing);
  });

  testWidgets('sorting sheets, offline content (US-120)', (t) async {
    final o = await as('leila', 'citizen');
    await pumpIt(t, const TipsScreen(), o);
    expect(find.text('📶 Disponible hors ligne'), findsOneWidget);
    expect(find.text('Verre'), findsOneWidget);
    await pumpIt(t, const TipSheetScreen(sheetName: 'glass'), o);
    expect(find.text('✅ Ce qui se recycle'), findsOneWidget);
    expect(find.text('Pots de confiture et bocaux'), findsOneWidget);
    expect(find.text('Miroirs et vitres'), findsOneWidget);
  });

  testWidgets('join a neighbourhood challenge and see the leaderboard (US-121)', (t) async {
    final o = await as('leila', 'citizen');
    await db.doc('wallets/leila').set({'earned': 0, 'kg': 10.0});
    await db.doc('challenges/ch1').set({
      'title': 'Octobre propre',
      'description': 'Objectif 500 kg à Sousse',
      'zoneId': null,
      'goalKg': 500.0,
      'rewardPoints': 50,
      'startAt': DateTime(2026, 10, 1),
      'endAt': DateTime(2026, 10, 31),
      'totalKg': 120.0,
      'participants': 1,
    });
    await db.doc('challenges/ch1/participants/karim').set({
      'uid': 'karim',
      'name': 'Karim B.',
      'zoneId': 'sousse',
      'baseKg': 0.0,
      'kg': 120.0,
    });
    await pumpIt(t, const ChallengesScreen(), o);
    expect(find.text('Octobre propre'), findsOneWidget);
    expect(find.text('120,00 kg sur 500,00 kg'), findsOneWidget);
    expect(find.text('⏳ 16 jours restants'), findsOneWidget);

    await pumpIt(t, const ChallengeDetailScreen(challengeId: 'ch1'), o);
    expect(find.text('Karim B.'), findsOneWidget);
    await t.ensureVisible(find.text('Je participe'));
    await t.tap(find.text('Je participe'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
    await settle(t);
    final p = (await db.doc('challenges/ch1/participants/leila').get()).data()!;
    expect((p['name'], p['baseKg']), ('Leila T.', 10.0));
    expect(find.text('Ma contribution'), findsOneWidget);
    expect(find.text('Leila T. · toi'), findsOneWidget);
  });

  testWidgets('admin sees the create button', (t) async {
    final o = await as('admin', 'admin');
    await pumpIt(t, const ChallengesScreen(), o);
    expect(find.text('Créer un défi'), findsOneWidget);
  });
}
