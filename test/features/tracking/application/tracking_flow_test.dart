import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/application/collection_actions_controller.dart';
import 'package:ecoflow/features/collection/data/collection_repository.dart';
import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/estimation/data/estimation_repositories.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/missions/application/mission_actions_controller.dart';
import 'package:ecoflow/features/missions/application/missions_providers.dart';
import 'package:ecoflow/features/tracking/application/chat_controller.dart';
import 'package:ecoflow/features/tracking/application/tracking_providers.dart';
import 'package:ecoflow/features/tracking/domain/eta.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/tracking_fakes.dart';

const line = EstimateLine(
  categoryId: 'can',
  count: 3,
  kg: 2,
  priceDtPerKg: 4,
  method: EstimationMethod.container,
);

void main() {
  late FakeFirebaseFirestore db;
  late String id;
  var now = DateTime(2026, 10, 1, 9);

  Future<ProviderContainer> as(String uid, {FakePositions? positions}) async {
    final c = await testContainer(
      positions: positions,
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: AuthUser(
              uid: uid,
              phoneNumber: '+21622000000',
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
      ..listen(missionActionsControllerProvider, (_, _) {})
      ..listen(collectionActionsControllerProvider, (_, _) {})
      ..listen(chatControllerProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  Future<List<Map<String, dynamic>>> notifs() async =>
      (await db.collection('notifications').get()).docs.map((d) => d.data()).toList();
  Future<CollectionRequest> fetch() async =>
      FirestoreCollectionRepository.fromDoc(await db.doc('collections/$id').get());

  setUp(() async {
    db = FakeFirebaseFirestore();
    now = DateTime(2026, 10, 1, 9);
    await db.doc('users/citizen').set({
      'displayName': 'Leila',
      'role': 'citizen',
      'status': 'active',
    });
    await db.doc('users/k').set({
      'displayName': 'K',
      'role': 'collector',
      'status': 'active',
      'verificationStatus': 'approved',
    });
    final code = await FirestoreEstimateRepository(db).create(
      const EstimateRecord(
        code: '',
        citizenUid: 'citizen',
        lines: [line],
        confidence: .8,
        priceScaleId: 'default',
      ),
    );
    id = await FirestoreCollectionRepository(db).create(
      CollectionRequest(
        id: '',
        citizenUid: 'citizen',
        estimateCode: code,
        place: const CollectionPlace(
          point: GeoPoint(35.8256, 10.6084),
          address: 'Rue 1, Sousse',
          zoneId: 'sousse',
        ),
        slot: TimeSlot(DateTime(2026, 10, 1), 10, 12),
        estimatedKg: 2,
        estimatedDt: 8,
      ),
    );
  });

  test('each status change notifies the citizen (US-065)', () async {
    final k = await as('k');
    final a = k.read(missionActionsControllerProvider.notifier);
    await a.accept(await fetch());
    await a.advance(await fetch());
    await a.advance(await fetch());
    await a.advance(await fetch()); // inProgress : pas de notification
    final types = [for (final n in await notifs()) n['type']];
    expect(types, ['assigned', 'onTheWay', 'arrived']);
    expect((await notifs()).every((n) => n['toUid'] == 'citizen' && n['fromUid'] == 'k'), isTrue);
    expect((await notifs()).firstWhere((n) => n['type'] == 'arrived')['critical'], isTrue);
  });

  test('citizen cancellation notifies the collector (US-065)', () async {
    final k = await as('k');
    await k.read(missionActionsControllerProvider.notifier).accept(await fetch());
    final c = await as('citizen');
    await c
        .read(collectionActionsControllerProvider.notifier)
        .cancel(await fetch(), stopSeries: true);
    expect((await notifs()).last, containsPair('type', 'cancelled'));
    expect((await notifs()).last, containsPair('toUid', 'k'));
  });

  test('live position published every 5 s while on the way, cleared after (US-063)', () async {
    final positions = FakePositions();
    final k = await as('k', positions: positions);
    k.listen(livePublisherProvider, (_, _) {});
    k.listen(myMissionsProvider, (_, _) {});
    final a = k.read(missionActionsControllerProvider.notifier);
    await a.accept(await fetch());
    await a.advance(await fetch());
    await pumpEventQueue();
    positions.controller.add(
      LivePosition(point: const GeoPoint(35.84, 10.61), at: now, speedKmh: 20),
    );
    await pumpEventQueue();
    positions.controller.add(LivePosition(point: const GeoPoint(35.85, 10.61), at: now));
    await pumpEventQueue();
    expect((await db.doc('liveLocations/$id').get()).data()!['point'], {
      'lat': 35.84,
      'lng': 10.61,
    }, reason: 'throttled');
    now = now.add(const Duration(seconds: 6));
    positions.controller.add(LivePosition(point: const GeoPoint(35.86, 10.61), at: now));
    await pumpEventQueue();
    expect((await db.doc('liveLocations/$id').get()).data()!['point'], {
      'lat': 35.86,
      'lng': 10.61,
    });
    await a.advance(await fetch()); // arrivé : encore visible
    await a.advance(await fetch()); // en cours : effacé
    await pumpEventQueue();
    expect((await db.doc('liveLocations/$id').get()).exists, isFalse);
  });

  test('chat masks numbers and notifies the other party (US-067)', () async {
    final k = await as('k');
    await k.read(missionActionsControllerProvider.notifier).accept(await fetch());
    final c = await as('citizen');
    expect(
      await c.read(chatControllerProvider.notifier).send(id, 'Mon numéro : 22 123 456'),
      isTrue,
    );
    final msg = (await db.collection('collections/$id/messages').get()).docs.single.data();
    expect(msg['text'], 'Mon numéro : •••• ••••');
    final n = (await notifs()).last;
    expect(n['type'], 'message');
    expect(n['toUid'], 'k');
    expect(n['preview'], 'Mon numéro : •••• ••••');
    expect(await c.read(chatControllerProvider.notifier).send(id, '   '), isFalse);
  });
}
