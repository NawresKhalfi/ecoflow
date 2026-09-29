import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/estimation/data/estimation_repositories.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/estimation/domain/weighing.dart';
import 'package:ecoflow/features/estimation/presentation/screens/estimates_screen.dart';
import 'package:ecoflow/features/estimation/presentation/screens/pricing_screen.dart';
import 'package:ecoflow/features/estimation/presentation/screens/weighing_screen.dart';
import 'package:ecoflow/features/scan/application/scan_providers.dart';
import 'package:ecoflow/features/scan/presentation/screens/scan_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/scan_fakes.dart';
import '../../../helpers/test_app.dart';

const line = EstimateLine(
  categoryId: 'can',
  count: 3,
  kg: 1,
  priceDtPerKg: 4,
  method: EstimationMethod.container,
);

void main() {
  late FakeFirebaseFirestore db;

  Future<List<Override>> as(String role, {String status = 'notRequired'}) async {
    db = FakeFirebaseFirestore();
    await db.doc('users/u').set({
      'displayName': 'Karim',
      'role': role,
      'status': 'active',
      'verificationStatus': status,
    });
    return [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          initialUser: const AuthUser(
            uid: 'u',
            phoneNumber: '+21622123456',
            providerIds: ['phone'],
          ),
        ),
      ),
      firestoreProvider.overrideWithValue(db),
    ];
  }

  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text).last);
    await t.tap(find.text(text).last);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await settle(t);
  }

  testWidgets('scan result shows the estimate, asks confirmation, then gives a code', (t) async {
    final picker = FakeScanPicker()..next = [(name: 'a.jpg', bytes: testJpeg())];
    final detector = FakeDetector()..result = [rawDet('metal', .9)];
    await pumpRoutedScreen(
      t,
      const ScanScreen(),
      size: const Size(420, 4200),
      overrides: [
        ...await as('citizen'),
        scanImagePickerProvider.overrideWithValue(picker),
        wasteDetectorProvider.overrideWithValue(detector),
        photoProcessorProvider.overrideWithValue(syncProcessor),
      ],
    );
    await tap(t, 'Importer de la galerie');
    await tap(t, 'Analyser');
    expect(find.text('⚖️ Estimation du poids et de la valeur'), findsOneWidget);
    expect(find.text('≈ 0,02 kg'), findsOneWidget, reason: '1 can × 15 g');
    expect(find.textContaining('Estimation peu fiable'), findsOneWidget);

    await tap(t, 'Sac 50 L');
    expect(find.textContaining('Estimation peu fiable'), findsNothing);
    expect(find.text('≈ 1,40 kg'), findsOneWidget, reason: '50 L × 0.8 × 35 g/L');

    await tap(t, 'Enregistrer l’estimation');
    expect(find.text('🔑 Code de pesée'), findsOneWidget);
    expect((await db.collection('estimates').get()).docs, hasLength(1));
  });

  testWidgets('weighing is locked for unverified collectors', (t) async {
    await pumpRoutedScreen(
      t,
      const WeighingScreen(),
      overrides: await as('collector', status: 'pending'),
    );
    expect(find.textContaining('doit être vérifié'), findsOneWidget);
    expect(find.text('Rechercher'), findsNothing);
  });

  testWidgets('verified collector weighs by code and sees the gap', (t) async {
    final o = await as('collector', status: 'approved');
    final code = await FirestoreEstimateRepository(db).create(
      const EstimateRecord(
        code: '',
        citizenUid: 'c',
        lines: [line],
        confidence: .8,
        priceScaleId: 'default',
      ),
    );
    await pumpRoutedScreen(t, const WeighingScreen(), size: const Size(420, 2000), overrides: o);
    await t.enterText(find.byType(TextFormField), code);
    await tap(t, 'Rechercher');
    expect(find.textContaining('Estimé'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).last, '1,5');
    await settle(t);
    expect(find.text('+50 %'), findsOneWidget);
    await tap(t, 'Valider la pesée');
    expect(find.textContaining('Pesée validée'), findsOneWidget);
    expect((await db.doc('estimates/$code').get()).data()!['finalDt'], 6);
  });

  testWidgets('citizen sees pending and weighed estimates, with comparison', (t) async {
    final o = await as('citizen');
    final repo = FirestoreEstimateRepository(db);
    const rec = EstimateRecord(
      code: '',
      citizenUid: 'u',
      lines: [line],
      confidence: .8,
      priceScaleId: 'default',
    );
    final pending = await repo.create(rec);
    final done = await repo.create(rec);
    await repo.submitWeighing(done, {'can': .5}, compareWeighing([line], {'can': .5}), 'k');
    await pumpRoutedScreen(t, const EstimatesScreen(), overrides: o);
    expect(find.text('⏳ En attente de pesée'), findsOneWidget);
    expect(find.text('✓ Pesée validée'), findsOneWidget);

    await pumpRoutedScreen(t, EstimateDetailScreen(code: done), overrides: o);
    expect(find.text('📊 Estimation vs pesée réelle'), findsOneWidget);
    expect(find.text('-50 %'), findsOneWidget);
    expect(find.text('2,000 DT'), findsOneWidget);
    expect(pending, isNot(done));
  });

  testWidgets('admin pricing shows default scale and calibration', (t) async {
    await pumpRoutedScreen(
      t,
      const PricingScreen(),
      size: const Size(420, 2400),
      overrides: await as('admin'),
    );
    expect(find.textContaining('Barème indicatif par défaut'), findsOneWidget);
    expect(find.text('Nouveau barème'), findsOneWidget);
    await tap(t, 'Analyser les pesées');
    expect(find.text('Aucune pesée validée pour l’instant.'), findsOneWidget);
  });
}
