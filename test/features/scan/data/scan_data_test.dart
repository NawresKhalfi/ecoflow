import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ecoflow/features/scan/data/catalog_repository.dart';
import 'package:ecoflow/features/scan/data/photo_processor.dart';
import 'package:ecoflow/features/scan/data/scan_repository.dart';
import 'package:ecoflow/features/scan/domain/detection.dart';
import 'package:ecoflow/features/scan/domain/scan_record.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List jpegWithGps({int w = 2000, int h = 1500}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(200, 180, 120));
  image.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(35, 1);
  image.exif.imageIfd['Make'] = img.IfdValueAscii('SpyPhone');
  return img.encodeJpg(image);
}

void main() {
  group('photo processing (US-012/021)', () {
    test('strips EXIF/GPS, resizes and measures quality', () {
      final original = jpegWithGps();
      expect(img.decodeJpgExif(original)?.gpsIfd.isEmpty, isFalse, reason: 'fixture has GPS');

      final p = processPhotoSync(original);
      expect(p.width, maxPhotoSide);
      expect(p.height, 768);
      final exif = img.decodeJpgExif(p.jpeg);
      expect(exif == null || (exif.gpsIfd.isEmpty && exif.imageIfd.isEmpty), isTrue);
      expect(p.metrics.brightness, greaterThan(150));
      expect(p.jpeg.length, lessThan(700 * 1024));
    });

    test('unreadable bytes raise UnreadablePhoto', () {
      expect(
        () => processPhotoSync(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<UnreadablePhoto>()),
      );
    });
  });

  group('scan repository', () {
    late FakeFirebaseFirestore db;
    late FirestoreScanRepository repo;
    final now = DateTime(2026, 9, 29);
    const det = Detection(
      id: 'p0-d0',
      photoIndex: 0,
      categoryId: 'can',
      confidence: .9,
      box: BoundingBox(0, 0, .5, .5),
    );
    ScanRecord scan({bool consent = true}) => ScanRecord(
      id: '',
      uid: 'u1',
      photoCount: 1,
      detections: const [det],
      originalDetections: const [det],
      modelVersionId: 'waste-yolov8m-v1',
      threshold: .35,
      inferenceMs: 900,
      trainingConsent: consent,
    );
    final photo = (jpeg: Uint8List.fromList([9, 8, 7]), width: 10, height: 10);

    setUp(() {
      db = FakeFirebaseFirestore();
      repo = FirestoreScanRepository(db);
    });

    test('saves scan, counts, recyclability, retention and photos', () async {
      final id = await repo.save(scan(), [photo], defaultCatalog, now: now);
      final m = (await db.doc('scans/$id').get()).data()!;
      expect(m['uid'], 'u1');
      expect(m['counts'], {'can': 1});
      expect(m['recyclability'], 'high');
      expect(m['corrected'], isFalse);
      expect((m['expiresAt'] as Timestamp).toDate(), now.add(photoRetention));
      expect((await repo.photos(id)).single.jpeg, [9, 8, 7]);
    });

    test('corrections are stored and exposed for training only with consent', () async {
      final a = await repo.save(scan(), [photo], defaultCatalog, now: now);
      final b = await repo.save(scan(consent: false), [photo], defaultCatalog, now: now);
      for (final id in [a, b]) {
        await repo.updateDetections(id, [det.relabel('glass')], defaultCatalog);
      }
      final m = (await db.doc('scans/$a').get()).data()!;
      expect(m['corrections'], {'added': 0, 'removed': 0, 'relabelled': 1});
      expect(m['counts'], {'glass': 1});
      final training = await repo.correctedForTraining();
      expect(training.map((s) => s.id), [a]);
      expect(training.single.detections.single.categoryId, 'glass');
    });

    test('purges expired photos only', () async {
      final old = await repo.save(
        scan(),
        [photo],
        defaultCatalog,
        now: now.subtract(const Duration(days: 100)),
      );
      final fresh = await repo.save(scan(), [photo], defaultCatalog, now: now);
      expect(await repo.purgeExpired(uid: 'u1', now: now), 1);
      expect(await repo.photos(old), isEmpty);
      expect(await repo.photos(fresh), hasLength(1));
      expect(await repo.purgeExpired(now: now), 0, reason: 'already purged');
    });
  });

  group('catalog repository (US-022)', () {
    test('default catalog until published, then CRUD', () async {
      final db = FakeFirebaseFirestore();
      final repo = FirestoreCatalogRepository(db);
      expect(await repo.watch().first, same(defaultCatalog));
      await repo.seedDefaults();
      expect((await repo.watch().first).length, defaultCatalog.length);
      await repo.save(
        const WasteCategory(
          id: 'hdpe',
          names: {'fr': 'Flacons HDPE'},
          emoji: '🧼',
          recyclability: Recyclability.high,
          order: 2,
        ),
      );
      await repo.delete('organic');
      final ids = (await repo.watch().first).map((c) => c.id);
      expect(ids, contains('hdpe'));
      expect(ids, isNot(contains('organic')));
      expect(() => repo.delete(otherCategoryId), throwsArgumentError);
    });
  });
}
