import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/application/collection_providers.dart';
import 'package:ecoflow/features/collection/data/collection_repository.dart';
import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/collection/presentation/screens/collection_detail_screen.dart';
import 'package:ecoflow/features/collection/presentation/screens/collections_screen.dart';
import 'package:ecoflow/features/collection/presentation/screens/request_form_screen.dart';
import 'package:ecoflow/features/collection/presentation/widgets/location_picker.dart';
import 'package:ecoflow/features/collection/presentation/widgets/presence_card.dart';
import 'package:ecoflow/features/estimation/data/estimation_repositories.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/profile/application/profile_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../helpers/collection_fakes.dart';
import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

const line = EstimateLine(categoryId: 'can', count: 3, kg: 2, priceDtPerKg: 4, method: EstimationMethod.container);

void main() {
  late FakeFirebaseFirestore db;
  final now = DateTime(2026, 9, 29, 9);

  Future<List<Override>> citizen({String role = 'citizen', String status = 'notRequired'}) async {
    db = FakeFirebaseFirestore();
    await db.doc('users/u').set({'displayName': 'Leila', 'role': role, 'status': 'active', 'verificationStatus': status});
    return [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository(
          initialUser: const AuthUser(uid: 'u', phoneNumber: '+21622123456', providerIds: ['phone']))),
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      mapTilesEnabledProvider.overrideWithValue(false),
      reverseGeocoderProvider.overrideWithValue(FakeGeocoder()),
      locationServiceProvider.overrideWithValue(FakeLocation((latitude: 35.8256, longitude: 10.6084))),
    ];
  }

  Future<String> estimate() => FirestoreEstimateRepository(db).create(
      const EstimateRecord(code: '', citizenUid: 'u', lines: [line], confidence: .8, priceScaleId: 'default'));

  Future<String> request(String code, {CollectionStatus? status}) async {
    final id = await FirestoreCollectionRepository(db).create(CollectionRequest(
      id: '',
      citizenUid: 'u',
      estimateCode: code,
      place: const CollectionPlace(point: GeoPoint(35.8256, 10.6084), address: 'Rue 1, Sousse', zoneId: 'sousse'),
      slot: upcomingSlots(now)[2],
      estimatedKg: 2,
      estimatedDt: 8,
    ));
    if (status != null) await db.doc('collections/$id').update({'status': status.name});
    return id;
  }

  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text).last);
    await t.tap(find.text(text).last);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
  }

  testWidgets('request form: GPS, zone, slot, instructions → detail with status', (t) async {
    final o = await citizen();
    final code = await estimate();
    await pumpRoutedScreen(t, RequestFormScreen(estimateCode: code), size: const Size(420, 3200), overrides: o);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect(find.text('📍 Emplacement'), findsOneWidget);
    await tap(t, '🛰️ Ma position GPS');
    expect(find.text('✓ Zone desservie : Sousse'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Rue de test, Sousse'), findsOneWidget);
    await tap(t, '14h–16h');
    await t.enterText(find.byType(TextFormField).last, 'Code 1234');
    await tap(t, 'Chaque semaine');
    await tap(t, 'Confirmer la demande');
    expect(find.textContaining('route:/app/collections/'), findsOneWidget);
    final doc = (await db.collection('collections').get()).docs.single.data();
    expect(doc['status'], 'noCollector', reason: 'no collector online');
    expect(doc['recurrence'], 'weekly');
  });

  testWidgets('detail: QR handover code, alternatives when nobody is available', (t) async {
    final o = await citizen();
    final code = await estimate();
    final id = await request(code, status: CollectionStatus.noCollector);
    await pumpRoutedScreen(t, CollectionDetailScreen(id: id), size: const Size(420, 2600), overrides: o);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect(find.text('Aucun collecteur disponible'), findsWidgets);
    expect(find.textContaining('Aucun collecteur disponible pour l’instant'), findsOneWidget);
    expect(find.text('Rester en file d’attente'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Changer de créneau'), findsOneWidget);
  });

  testWidgets('detail: confirm handover, then rate', (t) async {
    final o = await citizen();
    final code = await estimate();
    final id = await request(code, status: CollectionStatus.handedOver);
    await db.doc('collections/$id').update({'collectorUid': 'k'});
    await pumpRoutedScreen(t, CollectionDetailScreen(id: id), size: const Size(420, 2600), overrides: o);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect(find.text('Annuler la demande'), findsNothing);
    await tap(t, 'Confirmer la remise');
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect((await db.doc('collections/$id').get()).data()!['status'], 'completed');
    expect(find.text('⭐ Note ton collecteur'), findsOneWidget);
  });

  testWidgets('history list with status filter (US-038)', (t) async {
    final o = await citizen();
    await request(await estimate(), status: CollectionStatus.completed);
    await request(await estimate(), status: CollectionStatus.cancelled);
    await pumpRoutedScreen(t, const CollectionsScreen(), size: const Size(420, 1800), overrides: o);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect(find.text('Terminée'), findsOneWidget);
    expect(find.text('Annulée'), findsOneWidget);
    await tap(t, 'Terminées');
    expect(find.text('Annulée'), findsNothing);
  });

  testWidgets('collector presence card', (t) async {
    final o = await citizen(role: 'collector', status: 'approved');
    await pumpRoutedScreen(t, const PresenceCard(), overrides: o);
    expect(find.text('📡 Disponible pour des collectes'), findsOneWidget);
    await t.tap(find.byType(Switch));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect((await db.doc('collectorPresence/u').get()).data()!['online'], isTrue);
  });
}
