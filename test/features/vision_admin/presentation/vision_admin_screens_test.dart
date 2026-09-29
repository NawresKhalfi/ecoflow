import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/vision_admin/presentation/screens/catalog_screen.dart';
import 'package:ecoflow/features/vision_admin/presentation/screens/model_screen.dart';
import 'package:ecoflow/features/vision_admin/presentation/widgets/version_form.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';

void main() {
  testWidgets('catalog: default banner, then publish lists the classes', (t) async {
    final db = FakeFirebaseFirestore();
    await pumpRoutedScreen(
      t,
      const CatalogScreen(),
      size: const Size(420, 3000),
      overrides: [firestoreProvider.overrideWithValue(db)],
    );
    expect(find.textContaining('Catalogue par défaut'), findsOneWidget);
    expect(find.text('Bouteilles PET'), findsOneWidget);
    expect(find.text('🧠 plastic'), findsOneWidget);
    await t.tap(find.text('Publier le catalogue par défaut'));
    await settle(t);
    expect((await db.collection('wasteCategories').get()).docs, isNotEmpty);
    expect(find.text('Nouvelle classe'), findsOneWidget);
  });

  testWidgets('model: active version with honest metrics', (t) async {
    await pumpRoutedScreen(
      t,
      const ModelScreen(),
      size: const Size(420, 2600),
      overrides: [firestoreProvider.overrideWithValue(FakeFirebaseFirestore())],
    );
    expect(find.text('Waste YOLOv8m v1 (embarqué)'), findsWidgets);
    expect(find.text('74 %'), findsWidgets);
    expect(find.text('non mesuré'), findsNWidgets(2));
    expect(find.text('Exporter (ZIP YOLO)'), findsOneWidget);
    expect(find.text('Revenir à la version précédente'), findsNothing);
  });

  test('model source validation', () {
    expect(isValidModelSource('https://hf.co/m.tflite'), isTrue);
    expect(isValidModelSource('assets/models/x.tflite'), isTrue);
    expect(isValidModelSource('http://insecure'), isFalse);
    expect(parseRatio(''), isNull);
    expect(parseRatio('0,8'), .8);
    expect(parseRatio('3')!.isNaN, isTrue);
  });
}
