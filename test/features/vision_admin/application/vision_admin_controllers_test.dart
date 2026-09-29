import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/scan/application/scan_providers.dart';
import 'package:ecoflow/features/scan/data/scan_repository.dart';
import 'package:ecoflow/features/scan/domain/detection.dart';
import 'package:ecoflow/features/scan/domain/scan_record.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';
import 'package:ecoflow/features/vision_admin/application/vision_admin_controllers.dart';
import 'package:ecoflow/features/vision_admin/domain/model_version.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ProviderContainer c;

  setUp(() async {
    db = FakeFirebaseFirestore();
    c = await testContainer(overrides: [firestoreProvider.overrideWithValue(db)]);
    for (final p in [visionConfigProvider, modelVersionsProvider, catalogProvider]) {
      c.listen(p, (_, _) {});
    }
    for (final p in [
      modelAdminControllerProvider,
      datasetExportControllerProvider,
      catalogAdminControllerProvider,
    ]) {
      c.listen(p, (_, _) {});
    }
    await pumpEventQueue();
  });

  test('add, activate and roll back a model version (US-019)', () async {
    final m = c.read(modelAdminControllerProvider.notifier);
    await m.addVersion(
      const ModelVersion(
        id: 'v2',
        name: 'v2',
        iosModel: 'https://h/v2.mlpackage.zip',
        androidModel: 'https://h/v2.tflite',
      ),
    );
    await m.activate('v2');
    await pumpEventQueue();
    expect(c.read(activeModelProvider).id, 'v2');
    await m.rollback();
    await pumpEventQueue();
    expect(c.read(activeModelProvider).id, bundledModel.id);
    await m.setThreshold(.5);
    await pumpEventQueue();
    expect(c.read(visionConfigProvider).value!.confidenceThreshold, .5);
  });

  test('catalog publication (US-022)', () async {
    await c.read(catalogAdminControllerProvider.notifier).seedDefaults();
    expect((await db.collection('wasteCategories').get()).docs, hasLength(defaultCatalog.length));
  });

  test('export contains only consenting corrected scans (US-020)', () async {
    final repo = FirestoreScanRepository(db);
    const det = Detection(
      id: 'd',
      photoIndex: 0,
      categoryId: 'can',
      confidence: .9,
      box: BoundingBox(0, 0, .5, .5),
    );
    Future<String> scan(bool consent) => repo.save(
      ScanRecord(
        id: '',
        uid: 'u',
        photoCount: 1,
        detections: const [det],
        originalDetections: const [det],
        modelVersionId: 'm',
        threshold: .35,
        trainingConsent: consent,
      ),
      [
        (jpeg: Uint8List.fromList([1]), width: 1, height: 1),
      ],
      defaultCatalog,
      now: DateTime(2026, 9, 29),
    );
    final exporter = c.read(datasetExportControllerProvider.notifier);
    await expectLater(exporter.buildZip(), throwsA(isA<NothingToExport>()));

    final yes = await scan(true);
    final no = await scan(false);
    await scan(true); // consenti mais non corrigé
    for (final id in [yes, no]) {
      await repo.updateDetections(id, [det.relabel('glass')], defaultCatalog);
    }
    final zip = ZipDecoder().decodeBytes(await exporter.buildZip());
    expect(zip.files.where((f) => f.name.startsWith('images/')), hasLength(1));
    expect(exporter.lastExportCount, 1);
  });
}
