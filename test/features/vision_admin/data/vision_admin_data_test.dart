import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ecoflow/features/scan/domain/detection.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';
import 'package:ecoflow/features/vision_admin/data/dataset_exporter.dart';
import 'package:ecoflow/features/vision_admin/data/model_registry_repository.dart';
import 'package:ecoflow/features/vision_admin/domain/model_version.dart';
import 'package:ecoflow/features/vision_admin/domain/yolo_dataset.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry always lists the bundled model and persists config', () async {
    final repo = FirestoreModelRegistryRepository(FakeFirebaseFirestore());
    expect((await repo.watchVersions().first).single.id, bundledModel.id);
    await repo.addVersion(
      const ModelVersion(
        id: 'v2',
        name: 'v2',
        iosModel: 'https://x/a.mlpackage.zip',
        androidModel: 'https://x/a.tflite',
        map50: .6,
      ),
    );
    expect((await repo.watchVersions().first).map((v) => v.id), [bundledModel.id, 'v2']);
    expect((await repo.watchConfig().first).activeVersionId, bundledModel.id);
    await repo.saveConfig(const VisionConfig().activate('v2'));
    expect((await repo.watchConfig().first).activeVersionId, 'v2');
  });

  test('dataset zip has YOLO layout and no user identifiers', () {
    final zip = buildYoloDatasetZip([
      (
        jpeg: Uint8List.fromList([1, 2, 3]),
        annotations: const AnnotatedImage(
          name: 'img_00001',
          detections: [
            Detection(
              id: 'a',
              photoIndex: 0,
              categoryId: 'cardboard',
              confidence: .9,
              box: BoundingBox(0, 0, 1, 1),
            ),
          ],
        ),
      ),
    ], defaultCatalog);
    final archive = ZipDecoder().decodeBytes(zip);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, {'data.yaml', 'images/train/img_00001.jpg', 'labels/train/img_00001.txt'});
    final label = utf8.decode(archive.findFile('labels/train/img_00001.txt')!.content as List<int>);
    expect(label, '2 0.500000 0.500000 1.000000 1.000000');
  });
}
