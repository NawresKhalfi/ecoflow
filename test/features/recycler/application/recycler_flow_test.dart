import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/missions/application/collector_controllers.dart';
import 'package:ecoflow/features/missions/data/collector_repositories.dart';
import 'package:ecoflow/features/missions/domain/deposit.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:ecoflow/features/recycler/application/recycler_providers.dart';
import 'package:ecoflow/features/recycler/data/recycler_repository.dart';
import 'package:ecoflow/features/recycler/domain/analytics.dart';
import 'package:ecoflow/features/recycler/domain/purchasing.dart';
import 'package:ecoflow/features/recycler/domain/reception.dart';
import 'package:ecoflow/features/recycler/domain/stock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late RecyclerRepository repo;

  Deposit deposit(String id) => Deposit(
    id: id,
    collectorUid: 'k1',
    recyclerUid: 'rec',
    recyclerName: 'GreenPlast',
    missionIds: const ['m1', 'm2'],
    byCategoryKg: const {'pet_bottle': 6, 'can': 2},
    collectorName: 'Karim',
    zoneIds: const ['sousse'],
    missions: [
      MissionRef(id: 'm1', zoneId: 'sousse', day: DateTime(2026, 9, 30), kg: 5),
      MissionRef(id: 'm2', zoneId: 'sousse', day: DateTime(2026, 10, 1), kg: 3),
    ],
  );

  Future<List<StockLot>> lots() => repo.watchLots('rec').first;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = RecyclerRepository(db);
    await db.doc('deposits/d1').set({'recyclerUid': 'rec', 'status': 'pending'});
  });

  test('reception: one lot per weighed material, traceability, QC (US-080, US-084)', () async {
    final ids = await repo.receive(
      'rec',
      deposit('d1'),
      const ReceptionInput(
        kgByMaterial: {
          RecyclableMaterial.pet: 4,
          RecyclableMaterial.hdpe: 1.5,
          RecyclableMaterial.aluminium: 2,
          RecyclableMaterial.glass: 0,
        },
        grade: QualityGrade.b,
        contaminationPct: 5,
        note: 'Bouchons mélangés',
      ),
    );
    expect(ids, hasLength(3));
    final d = (await db.doc('deposits/d1').get()).data()!;
    expect((d['status'], d['quality'], d['contaminationPct']), ('confirmed', 'b', 5.0));
    expect(d['lotIds'], ids);
    final all = await lots();
    final pet = all.firstWhere((l) => l.material == RecyclableMaterial.pet);
    expect(
      (pet.kg, pet.grade, pet.collectorName, pet.depositId),
      (4.0, QualityGrade.b, 'Karim', 'd1'),
    );
    expect([for (final m in pet.missions) m.id], ['m1', 'm2']);
    expect(
      (await repo.watchMoves('rec').first).where((m) => m.reason == MoveReason.reception),
      hasLength(3),
    );
  });

  test('stock out and production (FIFO, traceability) (US-081, US-087)', () async {
    await repo.receive(
      'rec',
      deposit('d1'),
      const ReceptionInput(kgByMaterial: {RecyclableMaterial.pet: 10}, grade: QualityGrade.a),
    );
    await db.doc('deposits/d2').set({'recyclerUid': 'rec', 'status': 'pending'});
    await repo.receive(
      'rec',
      deposit('d2'),
      const ReceptionInput(kgByMaterial: {RecyclableMaterial.pet: 8}, grade: QualityGrade.a),
    );
    var all = await lots();
    final first = all.firstWhere((l) => l.depositId == 'd1');
    await db.doc('lots/${first.id}').update({'receivedAt': DateTime(2026, 9, 1)});
    await repo.moveOut('rec', first, 3, MoveReason.sale, 'Client');
    await expectLater(
      repo.moveOut('rec', first, 50, MoveReason.loss, ''),
      throwsA(isA<InsufficientStock>()),
    );
    all = await lots();
    final out = await repo.produce(
      'rec',
      all,
      const ProductionInput(
        material: RecyclableMaterial.pet,
        inputKg: 12,
        form: MaterialForm.flakes,
        outputKg: 11,
        grade: QualityGrade.a,
      ),
    );
    all = await lots();
    final byId = {for (final l in all) l.id: l};
    expect(byId[first.id]!.kg, 0, reason: '7 kg left, consumed first');
    expect(all.firstWhere((l) => l.depositId == 'd2').kg, 3);
    final flakes = byId[out]!;
    expect(
      (flakes.form, flakes.kg, flakes.source, flakes.marketplace),
      (MaterialForm.flakes, 11.0, LotSource.production, true),
    );
    expect(flakes.inputLotIds, hasLength(2));
    expect((await db.collection('productions').get()).docs.single.data()['outputLotId'], out);
    expect(
      stockSummary(all)[RecyclableMaterial.pet]![QualityGrade.a],
      14,
      reason: '3 raw + 11 flakes',
    );
  });

  test('purchase terms are shared with collectors (US-085)', () async {
    await db.doc('companies/rec').set({
      'legalName': 'GreenPlast',
      'city': 'Sousse',
      'status': 'approved',
    });
    await repo.savePurchasing('rec', {
      RecyclableMaterial.pet: const MaterialOffer(priceDtPerKg: .45, capacityKgMonth: 5000),
      RecyclableMaterial.glass: const MaterialOffer(accepting: false),
    });
    final offers = await repo.recyclerOffers();
    expect(offers.single.purchasing[RecyclableMaterial.pet]!.priceDtPerKg, .45);
    expect(offerValue(offers.single.purchasing, {RecyclableMaterial.glass: 1}), isNull);
  });

  test(
    'collector deposit carries a traceability snapshot and notifies the recycler (US-084, US-086)',
    () async {
      await db.doc('users/k1').set({
        'displayName': 'Karim',
        'role': 'collector',
        'status': 'active',
        'verificationStatus': 'approved',
      });
      await db.doc('estimates/E1').set({
        'citizenUid': 'c',
        'status': 'weighed',
        'actualKg': {'can': 2.5},
      });
      await db.doc('estimates/E2').set({
        'citizenUid': 'c',
        'status': 'weighed',
        'actualKg': {'pet_bottle': 1.5},
      });
      final c = await testContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              initialUser: const AuthUser(uid: 'k1', email: 'k@x.tn', providerIds: ['password']),
            ),
          ),
          firestoreProvider.overrideWithValue(db),
        ],
      );
      c
        ..listen(currentProfileProvider, (_, _) {})
        ..listen(depositControllerProvider, (_, _) {});
      await pumpEventQueue();
      CollectionRequest mission(String id, String code, String zone) => CollectionRequest(
        id: id,
        citizenUid: 'c',
        estimateCode: code,
        place: CollectionPlace(point: const GeoPoint(35.8, 10.6), address: 'Rue', zoneId: zone),
        slot: TimeSlot(DateTime(2026, 10, 1), 10, 12),
        estimatedKg: 2,
        estimatedDt: 8,
        status: CollectionStatus.completed,
      );
      await db.doc('collections/m1').set({'citizenUid': 'c'});
      await db.doc('collections/m2').set({'citizenUid': 'c'});
      final ok = await c
          .read(depositControllerProvider.notifier)
          .deposit(
            (uid: 'rec', name: 'GreenPlast', city: 'Sousse'),
            [mission('m1', 'E1', 'sousse'), mission('m2', 'E2', 'monastir')],
          );
      expect(ok, isTrue);
      final d = (await db.collection('deposits').where('collectorUid', isEqualTo: 'k1').get())
          .docs
          .single;
      expect(d.data()['collectorName'], 'Karim');
      expect(d.data()['zoneIds'], ['sousse', 'monastir']);
      expect(
        [for (final m in d.data()['missions'] as List) (m['id'], m['kg'])],
        [('m1', 2.5), ('m2', 1.5)],
      );
      final n = (await db.collection('notifications').get()).docs.single.data();
      expect(
        (n['toUid'], n['type'], n['collectionId'], n['preview']),
        ('rec', 'depositIncoming', d.id, '4.0 kg'),
      );
      final parsed = await FirestoreDepositRepository(db).watchIncoming('rec').first;
      expect(parsed.firstWhere((x) => x.id == d.id).missions.first.day, DateTime(2026, 10, 1));
    },
  );

  test('dashboard filter provider narrows the report (US-082)', () async {
    await repo.receive(
      'rec',
      deposit('d1'),
      const ReceptionInput(kgByMaterial: {RecyclableMaterial.pet: 10}, grade: QualityGrade.a),
    );
    final c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: const AuthUser(uid: 'rec', email: 'r@x.tn', providerIds: ['password']),
          ),
        ),
        firestoreProvider.overrideWithValue(db),
      ],
    );
    c.listen(supplyReportProvider, (_, _) {});
    await pumpEventQueue();
    expect(c.read(supplyReportProvider).totalKg, 10);
    c.read(dashboardFilterProvider.notifier).set(const DashboardFilter(zoneId: 'monastir'));
    expect(c.read(supplyReportProvider).totalKg, 0);
  });
}
