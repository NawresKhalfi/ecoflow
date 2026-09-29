import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/profile/data/document_picker.dart';
import 'package:ecoflow/features/scan/application/scan_controller.dart';
import 'package:ecoflow/features/scan/application/scan_providers.dart';
import 'package:ecoflow/features/scan/domain/image_quality.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/scan_fakes.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FakeScanPicker picker;
  late FakeDetector detector;
  late ProviderContainer c;

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('users/u').set({
      'displayName': 'Amine',
      'role': 'citizen',
      'status': 'active',
      'aiTrainingConsent': true,
    });
    picker = FakeScanPicker();
    detector = FakeDetector();
    c = await testContainer(
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
    c.listen(scanControllerProvider, (_, _) {});
    c.listen(currentProfileProvider, (_, _) {});
    await pumpEventQueue();
  });

  ScanController ctrl() => c.read(scanControllerProvider.notifier);
  ScanState state() => c.read(scanControllerProvider);

  test('imports up to 5 JPG/PNG photos and rejects other formats (US-012)', () async {
    picker.next = [
      for (var i = 0; i < 3; i++) (name: 'p$i.jpg', bytes: testJpeg()),
      (name: 'x.heic', bytes: testJpeg()),
    ];
    await ctrl().addPhotos(PickSource.gallery);
    expect(picker.lastMax, 5);
    expect(state().photos, hasLength(3));
    expect(state().error, ScanError.unsupportedFormat);
    expect(state().phase, ScanPhase.preview);

    picker.next = [for (var i = 0; i < 4; i++) (name: 'q$i.png', bytes: testJpeg())];
    await ctrl().addPhotos(PickSource.gallery);
    expect(picker.lastMax, 2);
    expect(state().photos, hasLength(5));
    await ctrl().addPhotos(PickSource.camera);
    expect(state().error, ScanError.tooManyPhotos);
  });

  test('dark photos are flagged before analysis (US-017)', () async {
    picker.next = [(name: 'dark.jpg', bytes: testJpeg(dark: true))];
    await ctrl().addPhotos(PickSource.camera);
    expect(state().photos.single.issues, contains(PhotoIssue.dark));
  });

  test('analyzes, counts, auto-saves and applies the threshold (US-011/013/014)', () async {
    picker.next = [(name: 'a.jpg', bytes: testJpeg())];
    await ctrl().addPhotos(PickSource.camera);
    detector.result = [rawDet('plastic', .9), rawDet('metal', .6), rawDet('plastic', .2)];
    await ctrl().analyze();
    expect(state().phase, ScanPhase.result);
    expect(state().visible, hasLength(2));
    expect(state().inferenceMs, isNotNull);
    expect(detector.seenModels.single, 'waste-yolov8m-v1');
    final id = state().scanId!;
    final doc = (await db.doc('scans/$id').get()).data()!;
    expect(doc['counts'], {'pet_bottle': 1, 'can': 1});
    expect(doc['trainingConsent'], isTrue);
    expect((await db.collection('scans/$id/photos').get()).docs, hasLength(1));

    ctrl().setThreshold(.15);
    expect(state().visible, hasLength(3));
  });

  test('corrections: relabel, remove, add, then save (US-016)', () async {
    picker.next = [(name: 'a.jpg', bytes: testJpeg())];
    await ctrl().addPhotos(PickSource.camera);
    detector.result = [rawDet('plastic', .9), rawDet('metal', .8)];
    await ctrl().analyze();
    final [first, second] = state().visible;
    ctrl().relabel(first.id, 'glass');
    ctrl().remove(second.id);
    ctrl().addManual('cardboard');
    expect(state().visible.map((d) => d.categoryId), ['glass', 'cardboard']);
    expect(await ctrl().saveCorrections(), isTrue);
    expect(state().correctionsSaved, isTrue);
    final doc = (await db.doc('scans/${state().scanId}').get()).data()!;
    expect(doc['corrections'], {'added': 1, 'removed': 1, 'relabelled': 1});
    expect(doc['counts'], {'cardboard': 1, 'glass': 1});
    expect((doc['originalDetections'] as List), hasLength(2), reason: 'AI proposal kept');
  });

  test('model failure is reported and photos are kept', () async {
    picker.next = [(name: 'a.jpg', bytes: testJpeg())];
    await ctrl().addPhotos(PickSource.camera);
    detector.fail = true;
    await ctrl().analyze();
    expect(state().error, ScanError.modelUnavailable);
    expect(state().phase, ScanPhase.preview);
    expect(state().photos, hasLength(1));
  });

  test('training consent is stored on the profile (US-020)', () async {
    await ctrl().setTrainingConsent(false);
    expect((await db.doc('users/u').get()).data()!['aiTrainingConsent'], isFalse);
  });
}
