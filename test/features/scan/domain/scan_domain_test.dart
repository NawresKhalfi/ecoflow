import 'dart:typed_data';

import 'package:ecoflow/features/scan/domain/detection.dart';
import 'package:ecoflow/features/scan/domain/image_quality.dart';
import 'package:ecoflow/features/scan/domain/scan_correction.dart';
import 'package:ecoflow/features/scan/domain/scan_rules.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';
import 'package:flutter_test/flutter_test.dart';

RawDetection raw(String label, double conf, [double size = .4]) =>
    RawDetection(label: label, confidence: conf, box: BoundingBox(.1, .1, .1 + size, .1 + size));

void main() {
  const catalog = defaultCatalog;

  group('catalog mapping (US-022)', () {
    test('model labels map to catalog categories, unknown → other', () {
      expect(categoryForLabel(catalog, 'plastic'), 'pet_bottle');
      expect(categoryForLabel(catalog, 'Metal'), 'can');
      expect(categoryForLabel(catalog, 'banana'), otherCategoryId);
    });

    test('inactive categories are ignored', () {
      final c = [for (final x in catalog) x.id == 'can' ? x.copyWith(active: false) : x];
      expect(categoryForLabel(c, 'metal'), otherCategoryId);
    });

    test('serialization round-trip', () {
      final pet = catalog.first;
      final back = WasteCategory.fromMap(pet.id, pet.toMap());
      expect(back.names['ar'], pet.names['ar']);
      expect(back.modelLabels, ['plastic']);
      expect(back.material, pet.material);
    });
  });

  group('detections, threshold and counts (US-013/014)', () {
    final dets = toDetections(
      [raw('plastic', .9), raw('plastic', .3), raw('metal', .8)],
      catalog,
      photoIndex: 0,
    );

    test('threshold hides low-confidence objects but keeps manual ones', () {
      expect(visibleDetections(dets, .35), hasLength(2));
      final manual = Detection(
        id: 'm',
        photoIndex: 0,
        categoryId: 'glass',
        confidence: 1,
        source: DetectionSource.manual,
      );
      expect(visibleDetections([...dets, manual], .99), [manual]);
    });

    test('counts by category ordered like the catalog', () {
      expect(countByCategory(visibleDetections(dets, .2), catalog), {'pet_bottle': 2, 'can': 1});
    });

    test('average confidence ignores manual additions', () {
      expect(averageConfidence(visibleDetections(dets, .35)), closeTo(.85, 1e-9));
      expect(averageConfidence(const []), isNull);
    });
  });

  group('recyclability (US-015)', () {
    Detection d(String c) => Detection(id: c, photoIndex: 0, categoryId: c, confidence: 1);

    test('levels and drivers', () {
      final high = estimateRecyclability([d('can'), d('cardboard'), d('can')], catalog)!;
      expect(high.level, Recyclability.high);
      expect(high.drivers.first, 'can');
      expect(estimateRecyclability([d('can'), d('organic')], catalog)!.level, Recyclability.medium);
      expect(
        estimateRecyclability([d('organic'), d('medical')], catalog)!.level,
        Recyclability.low,
      );
      expect(estimateRecyclability(const [], catalog), isNull);
    });
  });

  test('only JPG/PNG are accepted, 5 photos max (US-012)', () {
    expect(isAllowedImage('IMG_1.JPG'), isTrue);
    expect(isAllowedImage('a.png'), isTrue);
    expect(isAllowedImage('a.heic'), isFalse);
    expect(isAllowedImage('noext'), isFalse);
    expect(maxPhotosPerScan, 5);
  });

  group('photo quality (US-017)', () {
    test('uniform dark image is dark and blurry', () {
      final m = measurePhoto(Uint8List(64 * 64)..fillRange(0, 64 * 64, 20), 64, 64);
      expect(photoIssues(m), {PhotoIssue.dark, PhotoIssue.blurry});
    });

    test('bright checkerboard is sharp and well exposed', () {
      final g = Uint8List(64 * 64);
      for (var i = 0; i < g.length; i++) {
        g[i] = ((i % 64) ~/ 4 + (i ~/ 64) ~/ 4).isEven ? 230 : 90;
      }
      final m = measurePhoto(g, 64, 64);
      expect(m.brightness, greaterThan(100));
      expect(photoIssues(m), isEmpty);
    });

    test('framing: no object or only tiny objects', () {
      const ok = PhotoMetrics(brightness: 150, sharpness: 500);
      expect(photoIssues(ok, boxes: const []), {PhotoIssue.badFraming});
      expect(photoIssues(ok, boxes: const [BoundingBox(0, 0, .1, .1)]), {PhotoIssue.badFraming});
      expect(photoIssues(ok, boxes: const [BoundingBox(0, 0, .5, .5)]), isEmpty);
    });
  });

  test('correction summary (US-016)', () {
    final original = toDetections([raw('plastic', .9), raw('metal', .8)], catalog, photoIndex: 0);
    final corrected = [
      original[0].relabel('glass'),
      const Detection(id: 'new', photoIndex: 0, categoryId: 'can', confidence: 1),
    ];
    final s = summarizeCorrections(original, corrected);
    expect(s.toMap(), {'added': 1, 'removed': 1, 'relabelled': 1});
    expect(summarizeCorrections(original, original).hasChanges, isFalse);
    expect(corrected[0].originalCategoryId, 'pet_bottle');
  });

  test('bounding box YOLO format and serialization', () {
    const b = BoundingBox(.2, .4, .6, .8);
    expect(b.yolo[0], closeTo(.4, 1e-9));
    expect(b.yolo[1], closeTo(.6, 1e-9));
    expect(b.yolo[2], closeTo(.4, 1e-9));
    final d = Detection(id: 'x', photoIndex: 1, categoryId: 'can', confidence: .7, box: b);
    expect(Detection.fromMap(d.toMap()).box!.right, .6);
  });
}
