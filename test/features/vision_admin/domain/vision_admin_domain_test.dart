import 'package:ecoflow/features/scan/domain/detection.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';
import 'package:ecoflow/features/vision_admin/domain/model_version.dart';
import 'package:ecoflow/features/vision_admin/domain/yolo_dataset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('activation keeps history and rollback restores (US-019)', () {
    var c = const VisionConfig();
    expect(c.activeVersionId, bundledModel.id);
    expect(c.previousVersionId, isNull);
    c = c.activate('v2').activate('v3');
    expect(c.activeVersionId, 'v3');
    expect(c.history, [bundledModel.id, 'v2']);
    c = c.rollback();
    expect(c.activeVersionId, 'v2');
    c = c.rollback();
    expect(c.activeVersionId, bundledModel.id);
    expect(c.rollback().activeVersionId, bundledModel.id);
    expect(c.activate(bundledModel.id).history, isEmpty, reason: 're-activating is a no-op');
  });

  test('threshold is clamped and config round-trips', () {
    final c = const VisionConfig().activate('v2').withThreshold(1.4);
    expect(c.confidenceThreshold, .95);
    final back = VisionConfig.fromMap(c.toMap());
    expect(back.activeVersionId, 'v2');
    expect(back.history, [bundledModel.id]);
  });

  test('bundled model reports only published metrics', () {
    expect(bundledModel.recall, closeTo(.735, 1e-9));
    expect(bundledModel.precision, isNull);
    expect(bundledModel.map50, isNull);
  });

  test('YOLO label files and data.yaml (US-020)', () {
    const classes = defaultCatalog;
    final img = AnnotatedImage(
      name: 'img_00001',
      detections: const [
        Detection(
          id: 'a',
          photoIndex: 0,
          categoryId: 'can',
          confidence: .9,
          box: BoundingBox(0, 0, .5, .5),
        ),
        Detection(
          id: 'b',
          photoIndex: 0,
          categoryId: 'glass',
          confidence: 1,
        ), // sans cadre : ignoré
      ],
    );
    expect(yoloLabelFile(img, classes), '1 0.250000 0.250000 0.500000 0.500000');
    final yaml = yoloDataYaml(classes);
    expect(yaml, contains('nc: ${classes.length}'));
    expect(yaml, contains('  0: pet_bottle'));
  });
}
