import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/scan/application/scan_providers.dart';
import 'package:ecoflow/features/scan/presentation/screens/scan_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/scan_fakes.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeScanPicker picker;
  late FakeDetector detector;
  late FakeFirebaseFirestore db;

  setUp(() async {
    picker = FakeScanPicker();
    detector = FakeDetector();
    db = FakeFirebaseFirestore();
    await db.doc('users/u').set({'displayName': 'Amine', 'role': 'citizen', 'status': 'active'});
  });

  Future<void> pump(WidgetTester t) => pumpRoutedScreen(
    t,
    const ScanScreen(),
    size: const Size(420, 2600),
    overrides: [
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
      scanImagePickerProvider.overrideWithValue(picker),
      wasteDetectorProvider.overrideWithValue(detector),
      photoProcessorProvider.overrideWithValue(syncProcessor),
    ],
  );

  Future<void> tap(WidgetTester t, String text) async {
    await t.tap(find.text(text).last);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await settle(t);
  }

  testWidgets('empty state offers camera and gallery', (t) async {
    await pump(t);
    expect(find.text('Scanner tes déchets'), findsOneWidget);
    expect(find.text('Prendre la photo'), findsOneWidget);
    expect(find.text('Importer de la galerie'), findsOneWidget);
    expect(find.text('Analyser'), findsNothing);
  });

  testWidgets('photo → analysis → boxes, counts, recyclability, corrections', (t) async {
    await pump(t);
    picker.next = [(name: 'sac.jpg', bytes: testJpeg())];
    detector.result = [rawDet('metal', .92), rawDet('cardboard', .81)];
    await tap(t, 'Importer de la galerie');
    expect(find.text('1/5 photos'), findsOneWidget);

    await tap(t, 'Analyser');
    expect(find.text('Résultat de l’analyse'), findsOneWidget);
    expect(find.text('🥫 Canettes × 1'), findsOneWidget);
    expect(find.text('📦 Carton × 1'), findsOneWidget);
    expect(find.text('2 objets'), findsOneWidget);
    expect(find.text('Élevée'), findsOneWidget);
    expect(find.text('Canettes 92%'), findsOneWidget, reason: 'bounding box label');
    expect(find.text('Valider les corrections'), findsOneWidget);

    await t.ensureVisible(find.byIcon(Icons.delete_outline).first);
    await t.tap(find.byIcon(Icons.delete_outline).first);
    await settle(t);
    expect(find.text('1 objet'), findsOneWidget);
  });

  testWidgets('dark photo shows advice with retake', (t) async {
    await pump(t);
    picker.next = [(name: 'nuit.jpg', bytes: testJpeg(dark: true))];
    await tap(t, 'Prendre la photo');
    expect(find.text('⚠️ Photo à améliorer'), findsOneWidget);
    expect(find.textContaining('trop sombre'), findsOneWidget);
    expect(find.text('Reprendre la photo'), findsOneWidget);
  });
}
