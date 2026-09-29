import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/application/collection_actions_controller.dart';
import 'package:ecoflow/features/collection/application/collection_providers.dart';
import 'package:ecoflow/features/collection/application/request_form_controller.dart';
import 'package:ecoflow/features/collection/data/collection_repository.dart';
import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/feedback.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/estimation/data/estimation_repositories.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/estimation/domain/weighing.dart';
import 'package:ecoflow/features/profile/application/profile_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/collection_fakes.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

const line = EstimateLine(categoryId: 'can', count: 3, kg: 2, priceDtPerKg: 4, method: EstimationMethod.container);
const sousse = GeoPoint(35.8256, 10.6084);

void main() {
  late FakeFirebaseFirestore db;
  late ProviderContainer c;
  late DateTime now;
  late String code;
  final location = FakeLocation((latitude: 35.8256, longitude: 10.6084));

  setUp(() async {
    db = FakeFirebaseFirestore();
    now = DateTime(2026, 9, 29, 9);
    await db.doc('users/u').set({'displayName': 'Leila', 'role': 'citizen', 'status': 'active'});
    code = await FirestoreEstimateRepository(db).create(
        const EstimateRecord(code: '', citizenUid: 'u', lines: [line], confidence: .8, priceScaleId: 'default'));
    c = await testContainer(overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(
          initialUser: const AuthUser(uid: 'u', phoneNumber: '+21622123456', providerIds: ['phone']))),
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      reverseGeocoderProvider.overrideWithValue(FakeGeocoder()),
      locationServiceProvider.overrideWithValue(location),
    ]);
    c
      ..listen(currentProfileProvider, (_, _) {})
      ..listen(collectionConfigProvider, (_, _) {})
      ..listen(slotCountsProvider('sousse'), (_, _) {})
      ..listen(requestFormControllerProvider, (_, _) {})
      ..listen(collectionActionsControllerProvider, (_, _) {});
    await pumpEventQueue();
  });

  Future<void> online(String uid, GeoPoint p, {double cap = 200}) => db.doc('collectorPresence/$uid').set({
    'online': true,
    'point': p.toMap(),
    'capacityKg': cap,
  });

  Future<String> submit({TimeSlot? slot, Recurrence recurrence = Recurrence.none}) async {
    final f = c.read(requestFormControllerProvider.notifier);
    await f.load(code);
    await f.useGps();
    f.setSlot(slot ?? upcomingSlots(now)[1]);
    f.setInstructions('3e étage, code 1234');
    f.setRecurrence(recurrence);
    return (await f.submit())!;
  }

  Future<CollectionRequest> fetch(String id) async =>
      FirestoreCollectionRepository.fromDoc(await db.doc('collections/$id').get());

  test('form validates location, zone and slot (US-031/032)', () async {
    final f = c.read(requestFormControllerProvider.notifier);
    await f.load(code);
    expect(await f.submit(), isNull);
    expect(c.read(requestFormControllerProvider).error, RequestFormError.noLocation);

    await f.setPoint(const GeoPoint(33.5, 9.0));
    expect(await f.submit(), isNull);
    expect(c.read(requestFormControllerProvider).error, RequestFormError.outOfZone);

    await f.useGps();
    expect(c.read(requestFormControllerProvider).address, 'Rue de test, Sousse', reason: 'reverse geocoded');
    expect(await f.submit(), isNull);
    expect(c.read(requestFormControllerProvider).error, RequestFormError.noSlot);
  });

  test('full slot is refused (US-032)', () async {
    final slot = upcomingSlots(now)[1];
    await db.doc('slotCounters/sousse__${slot.id}').set({'count': 10, 'zoneId': 'sousse'});
    await pumpEventQueue();
    final f = c.read(requestFormControllerProvider.notifier);
    await f.load(code);
    await f.useGps();
    f.setSlot(slot);
    expect(await f.submit(), isNull);
    expect(c.read(requestFormControllerProvider).error, RequestFormError.slotFull);
  });

  test('creation reserves the slot, links the estimate and finds a collector (US-033/034)', () async {
    await online('near', const GeoPoint(35.83, 10.61));
    await online('small', const GeoPoint(35.826, 10.608), cap: 1);
    final id = await submit();
    final r = await fetch(id);
    expect(r.status, CollectionStatus.proposed);
    expect(r.proposedCollectorUid, 'near', reason: 'small lacks capacity');
    expect(r.searchRadiusKm, 5);
    expect(r.instructions, '3e étage, code 1234');
    expect((await db.doc('estimates/$code').get()).data()!['requestId'], id);
    final slot = upcomingSlots(now)[1];
    expect((await db.doc('slotCounters/sousse__${slot.id}').get()).data()!['count'], 1);
    expect(c.read(requestFormControllerProvider.notifier).zone!.id, 'sousse');
  });

  test('no collector → alternatives; retry once one comes online (US-036)', () async {
    final id = await submit();
    expect((await fetch(id)).status, CollectionStatus.noCollector);
    await online('k', const GeoPoint(35.9, 10.6));
    await c.read(collectionActionsControllerProvider.notifier).retryMatching(await fetch(id));
    final r = await fetch(id);
    expect(r.status, CollectionStatus.proposed);
    expect(r.searchRadiusKm, 10);
  });

  test('modify slot moves the reservation; too late is refused (US-035)', () async {
    final slots = upcomingSlots(now);
    final id = await submit(slot: slots[1]);
    final actions = c.read(collectionActionsControllerProvider.notifier);
    expect(await actions.modify(await fetch(id), slot: slots[3]), isTrue);
    expect((await db.doc('slotCounters/sousse__${slots[1].id}').get()).data()!['count'], 0);
    expect((await db.doc('slotCounters/sousse__${slots[3].id}').get()).data()!['count'], 1);
    expect((await fetch(id)).slot, slots[3]);

    now = slots[3].start.subtract(const Duration(minutes: 30));
    expect(await actions.modify(await fetch(id), instructions: 'x'), isFalse);
    expect(c.read(collectionActionsControllerProvider).error, isA<TooLateToModify>());
  });

  test('cancel: no penalty before acceptance, penalty after (US-035)', () async {
    final id = await submit();
    await c.read(collectionActionsControllerProvider.notifier).cancel(await fetch(id));
    final r = await fetch(id);
    expect(r.status, CollectionStatus.cancelled);
    expect(r.lateCancellation, isFalse);

    await db.doc('collections/$id').update({'status': 'accepted'});
    final accepted = await fetch(id);
    expect(accepted.cancellationPenalty, isTrue);
  });

  test('weighing hands over, citizen confirms, one rating, next recurrence (US-037/039/040)', () async {
    await online('k', const GeoPoint(35.83, 10.61));
    final id = await submit(recurrence: Recurrence.weekly);
    // Pesée par le collecteur avec le code de remise (epic 3).
    await FirestoreEstimateRepository(db).submitWeighing(code, {'can': 2.5}, compareWeighing([line], {'can': 2.5}), 'k');
    var r = await fetch(id);
    expect(r.status, CollectionStatus.handedOver);
    expect(r.collectorUid, 'k');

    final actions = c.read(collectionActionsControllerProvider.notifier);
    await actions.confirmHandover(r);
    r = await fetch(id);
    expect(r.status, CollectionStatus.completed);

    final all = (await db.collection('collections').get()).docs;
    expect(all, hasLength(2), reason: 'weekly occurrence scheduled');
    final next = FirestoreCollectionRepository.fromDoc(all.firstWhere((d) => d.id != id));
    expect(next.slot.date, r.slot.date.add(const Duration(days: 7)));
    expect(next.estimateCode, isNot(code), reason: 'single-use handover code');

    expect(await actions.rate(r, 5, 'Très ponctuel'), isTrue);
    expect((await db.doc('collectorStats/k').get()).data(), {'ratingAvg': 5.0, 'ratingCount': 1});
    expect(await actions.rate(await fetch(id), 4, 'encore'), isFalse, reason: 'one rating per pickup');
  });

  test('problem report creates an admin ticket (US-041)', () async {
    final id = await submit();
    await c.read(collectionActionsControllerProvider.notifier)
        .report(await fetch(id), ProblemReason.weightDisputed, 'Poids trop faible', const []);
    final t = (await db.collection('tickets').get()).docs.single.data();
    expect(t['reason'], 'weightDisputed');
    expect(t['status'], 'open');
    expect(t['collectionId'], id);
  });

  test('collector presence toggle uses rounded GPS', () async {
    c.listen(presenceControllerProvider, (_, _) {});
    await c.read(presenceControllerProvider.notifier).setOnline(true);
    final p = (await db.doc('collectorPresence/u').get()).data()!;
    expect(p['online'], isTrue);
    expect(p['point'], {'lat': 35.83, 'lng': 10.61});
  });
}
