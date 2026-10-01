import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/auth/domain/user_role.dart';
import 'package:ecoflow/features/forecast/application/forecast_providers.dart';
import 'package:ecoflow/features/forecast/domain/zone_forecast.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/tracking_fakes.dart';

final now = DateTime(2026, 10, 1, 9);

/// 60 jours de collectes pesées à Sousse (PET et canettes), une demande
/// sans collecteur à Monastir.
Future<void> seedHistory(FakeFirebaseFirestore db) async {
  for (var d = 1; d <= 60; d++) {
    final day = now.subtract(Duration(days: d));
    final kg = d % 7 == 0 ? 2.0 : 6.0;
    await db.doc('estimates/E$d').set({
      'citizenUid': 'c',
      'status': 'weighed',
      'actualKg': {'pet_bottle': kg, 'can': 1.0},
    });
    await db.doc('collections/c$d').set({
      'citizenUid': 'c',
      'collectorUid': 'k1',
      'estimateCode': 'E$d',
      'status': 'completed',
      'completedAt': day,
      'createdAt': day,
      'place': {
        'point': {'lat': 35.8256 + d / 1000, 'lng': 10.6084},
        'address': 'Rue',
        'zoneId': 'sousse',
      },
    });
  }
  await db.doc('collections/m1').set({
    'citizenUid': 'c',
    'status': 'noCollector',
    'createdAt': now.subtract(const Duration(days: 2)),
    'place': {
      'point': {'lat': 35.7643, 'lng': 10.8113},
      'address': 'Rue',
      'zoneId': 'monastir',
    },
  });
  await db.doc('collectorPresence/k1').set({'capacityKg': 20.0, 'online': false});
}

void main() {
  late FakeFirebaseFirestore db;
  late FakeNotifier notifier;

  Future<ProviderContainer> admin() async {
    final c = await testContainer(
      notifier: notifier,
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: const AuthUser(
              uid: 'admin',
              phoneNumber: '+21622000001',
              providerIds: ['phone'],
            ),
          ),
        ),
        firestoreProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    c
      ..listen(sessionProvider, (_, _) {})
      ..listen(forecastControllerProvider, (_, _) {});
    for (var i = 0; i < 20 && c.read(sessionProvider).role == null; i++) {
      await pumpEventQueue();
    }
    expect(c.read(sessionProvider).role, UserRole.admin);
    return c;
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    notifier = FakeNotifier();
    await db.doc('users/admin').set({'displayName': 'Sarra', 'role': 'admin', 'status': 'active'});
    await seedHistory(db);
  });

  test('training publishes per-zone forecasts, accuracy and alerts (US-088, 091, 092)', () async {
    final c = await admin();
    expect(await c.read(forecastControllerProvider.notifier).retrain(), isTrue);
    final sousse = ZoneForecast.fromMap('sousse', (await db.doc('forecasts/sousse').get()).data()!);
    // ~6 kg de PET par jour, 2 kg un jour sur 7.
    expect(sousse.plastic!.next7, closeTo(38, 6));
    expect(sousse.groups[MaterialGroup.metal]!.next7, closeTo(7, 1.5));
    expect(sousse.mape, isNotNull);
    expect((await db.doc('forecasts/tunis').get()).exists, isFalse);
    final runs = (await db.collection('forecastRuns').get()).docs;
    expect(runs.single.data()['records'], 60);
    expect(runs.single.data()['trigger'], 'manual');
    // Capacité 20 kg × 5 = 100 kg/semaine < 45 kg ? non ; ≈ 45 kg prévus.
    final alerts = [for (final a in runs.single.data()['alerts'] as List) (a['zoneId'], a['kind'])];
    expect(alerts, isNot(contains(('sousse', 'overload'))));
    await db.doc('collectorPresence/k1').set({'capacityKg': 8.0});
    await c.read(forecastControllerProvider.notifier).retrain();
    final last = (await db.collection('forecastRuns').get()).docs
        .map((d) => d.data())
        .firstWhere((d) => (d['alerts'] as List).isNotEmpty);
    expect([for (final a in last['alerts'] as List) a['kind']], contains('overload'));
  });

  test('automatic retraining only when the last run is older than 24 h (US-093)', () async {
    await db.collection('forecastRuns').add({
      'at': now.subtract(const Duration(hours: 3)),
      'records': 1,
    });
    var c = await admin();
    c.listen(autoRetrainProvider, (_, _) {});
    await c.read(autoRetrainProvider.future);
    expect((await db.collection('forecastRuns').get()).docs, hasLength(1));
    c.dispose();

    await db.doc('collectorPresence/k1').set({'capacityKg': 5.0});
    for (final d in (await db.collection('forecastRuns').get()).docs) {
      await d.reference.update({'at': now.subtract(const Duration(days: 2))});
    }
    c = await admin();
    c.listen(autoRetrainProvider, (_, _) {});
    await pumpEventQueue();
    await c.read(autoRetrainProvider.future);
    final runs = (await db.collection('forecastRuns').get()).docs.map((d) => d.data());
    expect(runs.where((r) => r['trigger'] == 'auto'), hasLength(1));
    expect(notifier.shown.single.payload, '/app/forecast-admin');
    expect(notifier.shown.single.title, contains('alerte'));
  });
}
