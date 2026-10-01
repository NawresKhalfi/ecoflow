import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/impact/application/impact_providers.dart';
import 'package:ecoflow/features/impact/domain/challenge.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  var now = DateTime(2026, 10, 10);

  Future<ProviderContainer> as(String uid) async {
    final c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: AuthUser(
              uid: uid,
              phoneNumber: '+21622000002',
              providerIds: const ['phone'],
            ),
          ),
        ),
        firestoreProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    c
      ..listen(currentProfileProvider, (_, _) {})
      ..listen(challengeControllerProvider, (_, _) {})
      ..listen(challengesProvider, (_, _) {})
      ..listen(visibleChallengesProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  Future<Map<String, dynamic>> doc(String path) async => (await db.doc(path).get()).data()!;

  setUp(() async {
    now = DateTime(2026, 10, 10);
    db = FakeFirebaseFirestore();
    await db.doc('users/admin').set({
      'displayName': 'Sarra Admin',
      'role': 'admin',
      'status': 'active',
    });
    await db.doc('users/leila').set({
      'displayName': 'Leila Trabelsi',
      'role': 'citizen',
      'status': 'active',
    });
    await db.doc('wallets/leila').set({'earned': 120, 'spent': 0, 'expired': 0, 'kg': 42.5});
    await db.doc('collections/c1').set({
      'citizenUid': 'leila',
      'status': 'completed',
      'place': {
        'zoneId': 'sousse',
        'address': 'Rue',
        'point': {'lat': 35.8, 'lng': 10.6},
      },
    });
  });

  test('admin launches a challenge, traced in the audit log', () async {
    final admin = await as('admin');
    final draft = Challenge(
      id: '',
      title: 'Octobre propre',
      goalKg: 50,
      rewardPoints: 30,
      startAt: now,
      endAt: now.add(const Duration(days: 14)),
      zoneId: 'sousse',
    );
    expect(
      await admin
          .read(challengeControllerProvider.notifier)
          .create(
            Challenge(
              id: '',
              title: '',
              goalKg: 50,
              startAt: now,
              endAt: now.add(const Duration(days: 1)),
            ),
          ),
      isFalse,
    );
    expect(await admin.read(challengeControllerProvider.notifier).create(draft), isTrue);
    final c = (await db.collection('challenges').get()).docs.single.data();
    expect(
      (c['title'], c['totalKg'], c['participants'], c['createdBy']),
      ('Octobre propre', 0.0, 0, 'admin'),
    );
    expect(
      (await db.collection('auditLog').get()).docs.single.data()['action'],
      'challenge.create',
    );
  });

  test('join, progress from the wallet, then claim the reward', () async {
    await db.doc('challenges/ch1').set({
      'title': 'Octobre propre',
      'description': '',
      'zoneId': 'sousse',
      'goalKg': 10.0,
      'rewardPoints': 30,
      'startAt': DateTime(2026, 10, 1),
      'endAt': DateTime(2026, 10, 20),
      'totalKg': 0.0,
      'participants': 0,
      'lastParticipant': null,
    });
    final c = await as('leila');
    await pumpEventQueue();
    final ctrl = c.read(challengeControllerProvider.notifier);
    final ch = c.read(visibleChallengesProvider).single;
    expect(await ctrl.join(ch), isTrue);
    var p = await doc('challenges/ch1/participants/leila');
    expect((p['name'], p['baseKg'], p['kg'], p['zoneId']), ('Leila T.', 42.5, 0.0, 'sousse'));
    expect((await doc('challenges/ch1'))['participants'], 1);

    // Une pesée validée fait monter le compteur du wallet.
    await db.doc('wallets/leila').update({'kg': 54.0});
    expect(await ctrl.syncActive([ch]), 11.5);
    p = await doc('challenges/ch1/participants/leila');
    expect(p['kg'], 11.5);
    expect((await doc('challenges/ch1'))['totalKg'], 11.5);
    expect(await ctrl.syncActive([ch]), 0, reason: 'nothing new');

    await pumpEventQueue();
    final live = c.read(challengeProvider('ch1')).value ?? ch;
    expect(await ctrl.claim(live), isFalse, reason: 'challenge still running');
    now = DateTime(2026, 10, 21);
    final ended = (await c.read(challengeRepositoryProvider).watch('ch1').first)!;
    expect(await ctrl.claim(ended), isTrue);
    final w = await doc('wallets/leila');
    expect((w['earned'], w['lastEntryId']), (150, 'ch_ch1_leila'));
    final e = await doc('pointEntries/ch_ch1_leila');
    expect((e['type'], e['points'], e['challengeId']), ('challenge', 30, 'ch1'));
  });

  test('ended or unachieved challenges refuse joining and rewards', () async {
    await db.doc('challenges/old').set({
      'title': 'Septembre',
      'goalKg': 100.0,
      'rewardPoints': 30,
      'startAt': DateTime(2026, 9, 1),
      'endAt': DateTime(2026, 9, 30),
      'totalKg': 20.0,
      'participants': 1,
    });
    await db.doc('challenges/old/participants/leila').set({
      'uid': 'leila',
      'name': 'Leila T.',
      'kg': 20.0,
    });
    final c = await as('leila');
    final ctrl = c.read(challengeControllerProvider.notifier);
    final old = (await c.read(challengeRepositoryProvider).watch('old').first)!;
    expect(await ctrl.join(old), isFalse);
    expect(await ctrl.claim(old), isFalse, reason: 'goal not reached');
    expect((await db.collection('pointEntries').get()).docs, isEmpty);
  });
}
