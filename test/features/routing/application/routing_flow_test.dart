import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/data/collection_repository.dart';
import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/estimation/data/estimation_repositories.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/missions/application/missions_providers.dart';
import 'package:ecoflow/features/routing/application/routing_providers.dart';
import 'package:ecoflow/features/routing/domain/optimization_config.dart';
import 'package:ecoflow/features/routing/domain/route_solver.dart';
import 'package:ecoflow/features/routing/domain/tour.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

const line = EstimateLine(
  categoryId: 'can',
  count: 3,
  kg: 2,
  priceDtPerKg: 4,
  method: EstimationMethod.container,
);
final now = DateTime(2026, 10, 1, 7);
final day = DateTime(2026, 10, 1);

Future<String> seed(
  FakeFirebaseFirestore db,
  String address,
  double lat,
  double lng, {
  int hour = 10,
  String? collector,
  CollectionStatus status = CollectionStatus.accepted,
  double kg = 3,
}) async {
  final code = await FirestoreEstimateRepository(db).create(
    const EstimateRecord(
      code: '',
      citizenUid: 'c',
      lines: [line],
      confidence: .8,
      priceScaleId: 'default',
    ),
  );
  final id = await FirestoreCollectionRepository(db).create(
    CollectionRequest(
      id: '',
      citizenUid: 'c',
      estimateCode: code,
      place: CollectionPlace(point: GeoPoint(lat, lng), address: address, zoneId: 'sousse'),
      slot: TimeSlot(day, hour, hour + 2),
      estimatedKg: kg,
      estimatedDt: 5,
      categories: const ['can'],
    ),
  );
  await db.doc('collections/$id').update({'status': status.name, 'collectorUid': ?collector});
  return id;
}

void main() {
  late FakeFirebaseFirestore db;
  late ProviderContainer c;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('users/k').set({
      'displayName': 'K',
      'role': 'collector',
      'status': 'active',
      'verificationStatus': 'approved',
    });
    await db.doc('collectorPresence/k').set({
      'online': true,
      'point': {'lat': 35.8256, 'lng': 10.6084},
    });
    c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: const AuthUser(
              uid: 'k',
              phoneNumber: '+21622000000',
              providerIds: ['phone'],
            ),
          ),
        ),
        firestoreProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    for (final p in [
      myMissionsProvider,
      openMissionsProvider,
      proposedToMeProvider,
      vehicleProvider,
      myPresenceDataProvider,
      optimizationConfigProvider,
      optimizationHistoryProvider,
    ]) {
      c.listen(p, (_, _) {});
    }
    c
      ..listen(tourPlanProvider, (_, _) {})
      ..listen(detourSuggestionsProvider, (_, _) {})
      ..listen(missionClustersProvider, (_, _) {})
      ..listen(optimizationAdminControllerProvider, (_, _) {});
  });

  test('tour plan orders the day\'s accepted missions and beats zig-zag (US-057/058)', () async {
    await seed(db, 'far', 35.8656, 10.6084, collector: 'k');
    await seed(db, 'near', 35.8356, 10.6084, collector: 'k');
    await seed(db, 'mid', 35.8506, 10.6084, collector: 'k');
    await pumpEventQueue();
    final plan = c.read(tourPlanProvider)!;
    expect(plan.tour.order.map((s) => s.label), ['near', 'mid', 'far']);
    expect(plan.tour.visits.first.waitMinutes, lessThan(1), reason: 'leaves just in time');
    expect(plan.tour.visits.first.arrival, DateTime(2026, 10, 1, 10));
    expect(plan.startAt.isBefore(DateTime(2026, 10, 1, 10)), isTrue);
    expect(tourRespectsConstraints(plan.tour, plan.capacityKg), isTrue);
    expect(plan.computeMs, lessThan(10000));
  });

  test('recalculated live when a mission is added or cancelled (US-059)', () async {
    await seed(db, 'a', 35.8356, 10.6084, collector: 'k');
    await pumpEventQueue();
    expect(c.read(tourPlanProvider)!.tour.order, hasLength(1));
    final b = await seed(db, 'b', 35.8456, 10.6084, collector: 'k');
    await pumpEventQueue();
    expect(c.read(tourPlanProvider)!.tour.order, hasLength(2));
    await db.doc('collections/$b').update({'status': 'cancelled'});
    await pumpEventQueue();
    expect(c.read(tourPlanProvider)!.tour.order.map((s) => s.label), ['a']);
  });

  test('capacity from the vehicle forces an unload visit (US-058)', () async {
    await db.doc('users/k').update({
      'vehicle': {'type': 'cargoBike', 'capacityKg': 10.0, 'volumeM3': .5},
    });
    for (var i = 0; i < 3; i++) {
      await seed(db, 's$i', 35.83 + i * .005, 10.61, collector: 'k', kg: 6);
    }
    await pumpEventQueue();
    final t = c.read(tourPlanProvider)!.tour;
    expect(t.visits.where((v) => v.kind == VisitKind.unload), isNotEmpty);
    expect(tourRespectsConstraints(t, 10), isTrue);
  });

  test('open missions on the way are suggested within max detour (US-061)', () async {
    await seed(db, 'a', 35.8356, 10.6084, collector: 'k');
    await seed(db, 'b', 35.8656, 10.6084, collector: 'k');
    await seed(db, 'onway', 35.8506, 10.6090, status: CollectionStatus.searching);
    await seed(db, 'far', 35.8506, 10.7500, status: CollectionStatus.searching);
    await pumpEventQueue();
    expect(c.read(detourSuggestionsProvider).map((e) => e.$1.place.address), ['onway']);
  });

  test('nearby open missions are grouped (US-056)', () async {
    await seed(db, 'x1', 35.8300, 10.6100, status: CollectionStatus.searching);
    await seed(db, 'x2', 35.8320, 10.6110, status: CollectionStatus.searching);
    await seed(db, 'lonely', 35.9500, 10.6100, status: CollectionStatus.searching);
    await pumpEventQueue();
    final clusters = c.read(missionClustersProvider);
    expect(clusters.single.$1.map((m) => m.place.address).toSet(), {'x1', 'x2'});
  });

  test('admin publishes parameters with history; solver uses them (US-062)', () async {
    await db.doc('users/k').update({'role': 'admin'});
    await c
        .read(optimizationAdminControllerProvider.notifier)
        .publish(const OptimizationConfig(maxDetourKm: 7, speedKmh: 40));
    await pumpEventQueue();
    expect(c.read(optimizationConfigProvider).value!.maxDetourKm, 7);
    expect(c.read(routeSolverProvider).config.speedKmh, 40);
    expect(
      (await db.collection('config/optimization/history').get()).docs.single.data()['by'],
      'k',
    );
  });

  test('end-of-day summary on completed pickups (US-060)', () async {
    await seed(db, 'far', 35.8656, 10.6084, collector: 'k', status: CollectionStatus.completed);
    await seed(
      db,
      'near',
      35.8356,
      10.6084,
      collector: 'k',
      status: CollectionStatus.completed,
      hour: 10,
    );
    await pumpEventQueue();
    c.listen(lastTourSavingsProvider, (_, _) {});
    final (d, count, _) = c.read(lastTourSavingsProvider)!;
    expect(d, day);
    expect(count, 2);
  });
}
