import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/data/collection_repository.dart';
import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/collection/presentation/widgets/location_picker.dart';
import 'package:ecoflow/features/estimation/data/estimation_repositories.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/missions/presentation/screens/earnings_screen.dart';
import 'package:ecoflow/features/missions/presentation/screens/mission_detail_screen.dart';
import 'package:ecoflow/features/missions/presentation/screens/missions_screen.dart';
import 'package:ecoflow/features/missions/presentation/screens/receptions_screen.dart';
import 'package:ecoflow/features/missions/presentation/screens/vehicle_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
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

void main() {
  late FakeFirebaseFirestore db;
  final now = DateTime(2026, 9, 30, 9);

  Future<List<Override>> as(String uid, String role) async {
    await db.doc('users/$uid').set({
      'displayName': uid,
      'role': role,
      'status': 'active',
      'verificationStatus': 'approved',
    });
    return [
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
      mapTilesEnabledProvider.overrideWithValue(false),
    ];
  }

  Future<String> request({
    CollectionStatus status = CollectionStatus.searching,
    String? proposedTo,
    String? collector,
  }) async {
    final code = await FirestoreEstimateRepository(db).create(
      const EstimateRecord(
        code: '',
        citizenUid: 'citizen',
        lines: [line],
        confidence: .8,
        priceScaleId: 'default',
      ),
    );
    final id = await FirestoreCollectionRepository(db).create(
      CollectionRequest(
        id: '',
        citizenUid: 'citizen',
        estimateCode: code,
        place: const CollectionPlace(
          point: GeoPoint(35.8256, 10.6084),
          address: 'Rue Ibn Khaldoun',
          zoneId: 'sousse',
        ),
        slot: upcomingSlots(now)[1],
        estimatedKg: 2,
        estimatedDt: 8,
        categories: const ['can'],
      ),
    );
    await db.doc('collections/$id').update({
      'status': status.name,
      'proposedCollectorUid': ?proposedTo,
      'collectorUid': ?collector,
      if (proposedTo != null) 'proposedAt': now.subtract(const Duration(seconds: 20)),
    });
    return id;
  }

  Future<void> pumpIt(WidgetTester t, Widget w, List<Override> o, {double h = 2400}) async {
    await pumpRoutedScreen(t, w, overrides: o, size: Size(420, h));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
  }

  setUp(() => db = FakeFirebaseFirestore());

  testWidgets('offline collectors are asked to go online (US-042)', (t) async {
    final o = await as('k1', 'collector');
    await request();
    await pumpIt(t, const MissionsScreen(), o);
    expect(find.text('Passe en ligne pour recevoir des missions.'), findsOneWidget);
  });

  testWidgets('online: proposed mission with countdown and open mission (US-043/044)', (t) async {
    final o = await as('k1', 'collector');
    await db.doc('collectorPresence/k1').set({
      'online': true,
      'point': {'lat': 35.83, 'lng': 10.61},
    });
    await request(status: CollectionStatus.proposed, proposedTo: 'k1');
    await request();
    await pumpIt(t, const MissionsScreen(), o);
    expect(find.text('Rue Ibn Khaldoun'), findsNWidgets(2));
    expect(find.text('⭐ Proposée pour toi'), findsOneWidget);
    expect(find.textContaining('s pour répondre'), findsOneWidget);
    expect(find.text('Refuser'), findsOneWidget);
    expect(find.text('Accepter'), findsNWidgets(2));
    await t.ensureVisible(find.text('Accepter').last);
    await t.tap(find.text('Accepter').last);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
    expect(find.textContaining('route:/app/missions/'), findsOneWidget);
  });

  testWidgets('in-progress mission shows proof and closing (US-048/050)', (t) async {
    final o = await as('k1', 'collector');
    final id = await request(status: CollectionStatus.inProgress, collector: 'k1');
    await pumpIt(t, MissionDetailScreen(id: id), o, h: 3200);
    expect(find.text('📷 Photo preuve'), findsOneWidget);
    expect(find.text('Prendre la photo preuve'), findsOneWidget);
    expect(find.text('✅ Clôturer la mission'), findsOneWidget);
    expect(find.text('⚠️ Citoyen absent / adresse introuvable'), findsOneWidget);
    expect(find.textContaining('Déchets estimés'), findsOneWidget);
  });

  testWidgets('accepted mission: navigation and next step (US-046/047)', (t) async {
    final o = await as('k1', 'collector');
    final id = await request(status: CollectionStatus.accepted, collector: 'k1');
    await pumpIt(t, MissionDetailScreen(id: id), o, h: 3200);
    expect(find.text('🧭 Google Maps'), findsOneWidget);
    expect(find.text('🧭 Waze'), findsOneWidget);
    await t.ensureVisible(find.text('Je pars (en route)'));
    await t.tap(find.text('Je pars (en route)'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
    expect((await db.doc('collections/$id').get()).data()!['status'], 'onTheWay');
  });

  testWidgets('earnings: totals and balance (US-051/052)', (t) async {
    final o = await as('k1', 'collector');
    await db.doc('earnings/m1').set({
      'collectorUid': 'k1',
      'amountDt': 12.5,
      'kg': 3.0,
      'createdAt': now,
    });
    await pumpIt(t, const EarningsScreen(), o, h: 2600);
    expect(find.text('12,500 DT'), findsWidgets);
    expect(find.text('Retirer mes revenus'), findsOneWidget);
    expect(find.text('Déposer ma tournée'), findsOneWidget);
  });

  testWidgets('recycler receives an incoming deposit into stock (US-055, US-080)', (t) async {
    final o = await as('rec', 'recycler');
    await db.doc('companies/rec').set({'legalName': 'GreenPlast', 'status': 'approved'});
    await db.collection('deposits').add({
      'collectorUid': 'k1',
      'recyclerUid': 'rec',
      'recyclerName': 'GreenPlast',
      'missionIds': ['m1'],
      'byCategoryKg': {'can': 4.0},
      'status': 'pending',
    });
    await pumpIt(t, const ReceptionsScreen(), o);
    expect(find.textContaining('1 lot en route'), findsOneWidget);
    await t.tap(find.text('Réceptionner'));
    await settle(t);
    // Canettes → aluminium, pré-rempli avec le poids déclaré.
    expect(find.widgetWithText(TextFormField, '4.0'), findsOneWidget);
    await t.tap(find.text('Qualité B'));
    await settle(t);
    await t.ensureVisible(find.text('Valider l’entrée en stock'));
    await t.tap(find.text('Valider l’entrée en stock'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
    final dep = (await db.collection('deposits').get()).docs.single.data();
    expect((dep['status'], dep['quality']), ('confirmed', 'b'));
    expect(dep['receivedKg'], {'aluminium': 4.0});
    final lot = (await db.collection('lots').get()).docs.single.data();
    expect(
      (lot['material'], lot['kg'], lot['grade'], lot['collectorUid']),
      ('aluminium', 4.0, 'b', 'k1'),
    );
  });

  testWidgets('vehicle form (US-054)', (t) async {
    final o = await as('k1', 'collector');
    await pumpIt(t, const VehicleScreen(), o);
    await t.tap(find.text('🚐 Camionnette'));
    await settle(t);
    await t.ensureVisible(find.text('Enregistrer'));
    await t.tap(find.text('Enregistrer'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
    expect((await db.doc('users/k1').get()).data()!['vehicle']['capacityKg'], 600);
  });
}
