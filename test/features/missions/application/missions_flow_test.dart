import 'dart:typed_data';

import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/application/collection_actions_controller.dart';
import 'package:ecoflow/features/collection/application/proposal_watcher.dart';
import 'package:ecoflow/features/collection/data/collection_repository.dart';
import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/estimation/data/estimation_repositories.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/estimation/domain/weighing.dart';
import 'package:ecoflow/features/missions/application/collector_controllers.dart';
import 'package:ecoflow/features/missions/application/mission_actions_controller.dart';
import 'package:ecoflow/features/missions/application/missions_providers.dart';
import 'package:ecoflow/features/missions/data/collector_repositories.dart';
import 'package:ecoflow/features/missions/data/mission_repository.dart';
import 'package:ecoflow/features/missions/domain/earnings.dart';
import 'package:ecoflow/features/missions/domain/vehicle.dart';
import 'package:ecoflow/features/profile/application/profile_providers.dart';
import 'package:ecoflow/features/profile/data/document_picker.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/collection_fakes.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

const line = EstimateLine(
  categoryId: 'can',
  count: 3,
  kg: 2,
  priceDtPerKg: 4,
  method: EstimationMethod.container,
);

class _Picker implements DocumentPicker {
  @override
  Future<PickedFile?> pick(PickSource source) async =>
      (name: 'proof.jpg', bytes: Uint8List.fromList([1, 2, 3]));
}

void main() {
  late FakeFirebaseFirestore db;
  late DateTime now;
  late String code;
  late String requestId;

  Future<ProviderContainer> as(String uid) async {
    final c = await testContainer(
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
        documentPickerProvider.overrideWithValue(_Picker()),
        locationServiceProvider.overrideWithValue(
          FakeLocation((latitude: 35.8256, longitude: 10.6084)),
        ),
      ],
    );
    c
      ..listen(currentProfileProvider, (_, _) {})
      ..listen(missionActionsControllerProvider, (_, _) {})
      ..listen(collectionActionsControllerProvider, (_, _) {})
      ..listen(earningsControllerProvider, (_, _) {})
      ..listen(depositControllerProvider, (_, _) {})
      ..listen(collectorSettingsControllerProvider, (_, _) {})
      ..listen(myMissionsProvider, (_, _) {})
      ..listen(earningsProvider, (_, _) {})
      ..listen(payoutsProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  Future<CollectionRequest> fetch() async =>
      FirestoreCollectionRepository.fromDoc(await db.doc('collections/$requestId').get());

  setUp(() async {
    db = FakeFirebaseFirestore();
    now = DateTime(2026, 9, 30, 9);
    await db.doc('users/citizen').set({
      'displayName': 'Leila',
      'role': 'citizen',
      'status': 'active',
    });
    for (final k in ['k1', 'k2']) {
      await db.doc('users/$k').set({
        'displayName': k,
        'role': 'collector',
        'status': 'active',
        'verificationStatus': 'approved',
      });
    }
    code = await FirestoreEstimateRepository(db).create(
      const EstimateRecord(
        code: '',
        citizenUid: 'citizen',
        lines: [line],
        confidence: .8,
        priceScaleId: 'default',
      ),
    );
    requestId = await FirestoreCollectionRepository(db).create(
      CollectionRequest(
        id: '',
        citizenUid: 'citizen',
        estimateCode: code,
        place: const CollectionPlace(
          point: GeoPoint(35.8256, 10.6084),
          address: 'Rue 1',
          zoneId: 'sousse',
        ),
        slot: upcomingSlots(now)[1],
        estimatedKg: 2,
        estimatedDt: 8,
        categories: const ['can'],
      ),
    );
  });

  test('first acceptance wins (US-044)', () async {
    final k1 = await as('k1');
    final k2 = await as('k2');
    expect(await k1.read(missionActionsControllerProvider.notifier).accept(await fetch()), isTrue);
    expect(await k2.read(missionActionsControllerProvider.notifier).accept(await fetch()), isFalse);
    expect(k2.read(missionActionsControllerProvider).error, isA<MissionTaken>());
    expect((await fetch()).collectorUid, 'k1');
  });

  test('refusal and 60 s expiry send the request back to matching (US-044)', () async {
    await db.doc('collectorPresence/k1').set({
      'online': true,
      'point': {'lat': 35.83, 'lng': 10.61},
      'capacityKg': 100,
    });
    await db.doc('collectorPresence/k2').set({
      'online': true,
      'point': {'lat': 35.84, 'lng': 10.61},
      'capacityKg': 100,
    });
    final citizen = await as('citizen');
    final watcher = ProposalWatcher(_RefProbe(citizen).ref);
    await watcher.check([await fetch()]);
    var r = await fetch();
    expect(r.status, CollectionStatus.proposed);
    final first = r.proposedCollectorUid!;

    final k = await as(first);
    await k.read(missionActionsControllerProvider.notifier).refuse(r);
    r = await fetch();
    expect(r.status, CollectionStatus.searching);
    await watcher.check([r]);
    r = await fetch();
    final second = r.proposedCollectorUid!;
    expect(second, isNot(first), reason: 'refused collector excluded');

    now = now.add(const Duration(seconds: 61));
    await watcher.check([r]);
    r = await fetch();
    expect(r.refusedBy, containsAll([first, second]));
    expect(r.status, CollectionStatus.noCollector);
  });

  test(
    'full mission: steps, proof, citizen code, confirmation, earnings (US-047/048/050/051)',
    () async {
      final k = await as('k1');
      final actions = k.read(missionActionsControllerProvider.notifier);
      await actions.accept(await fetch());
      for (final expected in [
        CollectionStatus.onTheWay,
        CollectionStatus.arrived,
        CollectionStatus.inProgress,
      ]) {
        await actions.advance(await fetch());
        expect((await fetch()).status, expected);
      }
      final history = (await db.doc('collections/$requestId').get()).data()!;
      expect(history['arrivedAt'], isNotNull, reason: 'timestamped');

      expect(
        await actions.close(await fetch(), code: code, actualKg: {'can': 2.5}, hasProof: false),
        isFalse,
      );
      expect(k.read(missionActionsControllerProvider).error, isA<ProofRequired>());
      await actions.takeProof(await fetch(), PickSource.camera);
      expect((await db.doc('collections/$requestId/attachments/proof').get()).exists, isTrue);
      expect(
        await actions.close(
          await fetch(),
          code: 'ZZZZZZZZ',
          actualKg: {'can': 2.5},
          hasProof: true,
        ),
        isFalse,
      );
      expect(k.read(missionActionsControllerProvider).error, isA<WrongHandoverCode>());
      expect(await actions.close(await fetch(), code: code, actualKg: {}, hasProof: true), isFalse);
      expect(k.read(missionActionsControllerProvider).error, isA<WeightsIncomplete>());
      expect(
        await actions.close(
          await fetch(),
          code: code.toLowerCase(),
          actualKg: {'can': 2.5},
          hasProof: true,
        ),
        isTrue,
      );
      expect((await fetch()).status, CollectionStatus.handedOver);

      final citizen = await as('citizen');
      await citizen
          .read(collectionActionsControllerProvider.notifier)
          .confirmHandover(await fetch());
      expect((await fetch()).status, CollectionStatus.completed);

      await k.read(earningsControllerProvider.notifier).syncCompleted([await fetch()], const []);
      final e = (await db.doc('earnings/$requestId').get()).data()!;
      expect(e['amountDt'], 10.0);
      expect(e['kg'], 2.5);
      await k.read(earningsControllerProvider.notifier).syncCompleted([await fetch()], const []);
      expect((await db.collection('earnings').get()).docs, hasLength(1), reason: 'idempotent');
    },
  );

  test('withdrawal requires 20 DT and enough balance (US-052)', () async {
    await FirestoreEarningsRepository(
      db,
    ).ensureEarning(missionId: 'm1', uid: 'k1', amountDt: 25, kg: 5);
    final k = await as('k1');
    final ctrl = k.read(earningsControllerProvider.notifier);
    expect(await ctrl.withdraw(10, PayoutMethod.cash), isFalse);
    expect(await ctrl.withdraw(30, PayoutMethod.cash), isFalse);
    expect(await ctrl.withdraw(25, PayoutMethod.bankTransfer), isTrue);
    await pumpEventQueue();
    expect(await ctrl.withdraw(20, PayoutMethod.cash), isFalse, reason: 'balance now 0');
    expect((await db.collection('payouts').get()).docs.single.data()['status'], 'requested');
    expect((await db.doc('collectorBalances/k1').get()).data(), containsPair('withdrawnDt', 25.0));
    await expectLater(
      FirestoreEarningsRepository(db).requestPayout('k1', 20, PayoutMethod.cash),
      throwsStateError,
      reason: 'repository refuses over-withdrawal too',
    );
  });

  test('no-show after arrival cancels without penalty and opens a ticket (US-053)', () async {
    final k = await as('k1');
    final actions = k.read(missionActionsControllerProvider.notifier);
    await actions.accept(await fetch());
    await actions.advance(await fetch());
    await actions.advance(await fetch());
    await actions.reportNoShow(
      await fetch(),
      NoShowReason.citizenAbsent,
      '3 appels sans réponse',
      null,
    );
    final r = await fetch();
    expect(r.status, CollectionStatus.cancelled);
    expect(r.cancelledBy, 'collector');
    expect(r.lateCancellation, isFalse);
    final t = (await db.collection('tickets').get()).docs.single.data();
    expect(t['reason'], 'citizenAbsent');
    expect(t['reporterRole'], 'collector');
    expect((await db.doc('slotCounters/sousse__${r.slot.id}').get()).data()!['count'], 0);
  });

  test('deposit to an approved recycler, who confirms (US-055)', () async {
    await db.doc('companies/rec').set({
      'legalName': 'GreenPlast',
      'city': 'Sousse',
      'status': 'approved',
    });
    await FirestoreEstimateRepository(
      db,
    ).submitWeighing(code, {'can': 2.5}, compareWeighingFor(), 'k1');
    await db.doc('collections/$requestId').update({'collectorUid': 'k1', 'status': 'completed'});
    final k = await as('k1');
    final ctrl = k.read(depositControllerProvider.notifier);
    final mine = await FirestoreMissionRepository(db).watchMine('k1').first;
    expect(ctrl.depositable(mine), hasLength(1));
    final recyclers = await FirestoreDepositRepository(db).approvedRecyclers();
    expect(await ctrl.deposit(recyclers.single, mine), isTrue);
    final dep = (await db.collection('deposits').get()).docs.single;
    expect(dep.data()['byCategoryKg'], {'can': 2.5});
    expect((await fetch()).depositId, dep.id);

    final rec = await as('rec');
    rec.listen(depositControllerProvider, (_, _) {});
    final incoming = await FirestoreDepositRepository(db).watchIncoming('rec').first;
    await rec.read(depositControllerProvider.notifier).review(incoming.single, confirmed: true);
    expect((await db.doc('deposits/${dep.id}').get()).data()!['status'], 'confirmed');
  });

  test('vehicle capacity feeds presence; work zone saved (US-042/054)', () async {
    final k = await as('k1');
    final s = k.read(collectorSettingsControllerProvider.notifier);
    await s.saveVehicle(Vehicle.defaultFor(VehicleType.van));
    expect((await db.doc('collectorPresence/k1').get()).data()!['capacityKg'], 600);
    await s.saveZone(10);
    expect((await db.doc('collectorPresence/k1').get()).data()!['workZone'], {
      'center': {'lat': 35.83, 'lng': 10.61},
      'radiusKm': 10.0,
    });
    k.listen(presenceControllerProvider, (_, _) {});
    await k.read(presenceControllerProvider.notifier).setOnline(true);
    await k.read(presenceControllerProvider.notifier).setOnline(false);
    expect(
      (await db.doc('collectorPresence/k1').get()).data()!.containsKey('point'),
      isFalse,
      reason: 'position shared only while online',
    );
  });
}

/// Pesée simple pour les tests de dépôt.
dynamic compareWeighingFor() => compareWeighing([line], {'can': 2.5});

/// Donne accès à un `Ref` d'un conteneur pour instancier le watcher.
class _RefProbe {
  _RefProbe(ProviderContainer c) : ref = c.read(_refProvider);
  final Ref ref;
}

final _refProvider = Provider<Ref>((ref) => ref);
