import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/estimation/application/estimate_draft_controller.dart';
import 'package:ecoflow/features/estimation/application/estimation_admin_controllers.dart';
import 'package:ecoflow/features/estimation/application/estimation_providers.dart';
import 'package:ecoflow/features/estimation/application/weighing_controller.dart';
import 'package:ecoflow/features/estimation/data/estimation_repositories.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/estimation/domain/estimation_coefficients.dart';
import 'package:ecoflow/features/estimation/domain/price_scale.dart';
import 'package:ecoflow/features/estimation/domain/weighing.dart';
import 'package:ecoflow/features/profile/data/document_picker.dart';
import 'package:ecoflow/features/scan/application/scan_controller.dart';
import 'package:ecoflow/features/scan/application/scan_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/scan_fakes.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;

  Future<ProviderContainer> container(
    String role, {
    String status = 'notRequired',
    String uid = 'u',
  }) async {
    db = FakeFirebaseFirestore();
    await db.doc('users/$uid').set({
      'displayName': 'X',
      'role': role,
      'status': 'active',
      'verificationStatus': status,
    });
    final picker = FakeScanPicker()..next = [(name: 'a.jpg', bytes: testJpeg())];
    final detector = FakeDetector()..result = [rawDet('plastic', .9), rawDet('metal', .9)];
    final c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: AuthUser(
              uid: uid,
              phoneNumber: '+21622123456',
              providerIds: const ['phone'],
            ),
          ),
        ),
        firestoreProvider.overrideWithValue(db),
        scanImagePickerProvider.overrideWithValue(picker),
        wasteDetectorProvider.overrideWithValue(detector),
        photoProcessorProvider.overrideWithValue(syncProcessor),
      ],
    );
    c
      ..listen(currentProfileProvider, (_, _) {})
      ..listen(scanControllerProvider, (_, _) {})
      ..listen(estimateDraftControllerProvider, (_, _) {})
      ..listen(draftEstimateProvider, (_, _) {})
      ..listen(weighingControllerProvider, (_, _) {})
      ..listen(coefficientsProvider, (_, _) {})
      ..listen(priceScalesProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  group('estimate draft (US-023 to US-026)', () {
    late ProviderContainer c;
    setUp(() async {
      c = await container('citizen');
      await c.read(scanControllerProvider.notifier).addPhotos(PickSource.gallery);
      await c.read(scanControllerProvider.notifier).analyze();
    });

    test('recomputes instantly and requires confirmation when unreliable', () async {
      final ctrl = c.read(estimateDraftControllerProvider.notifier);
      final count = c.read(draftEstimateProvider)!;
      expect(count.lines, hasLength(2));
      expect(count.needsConfirmation, isTrue);
      expect(await ctrl.save(), isNull, reason: 'not confirmed');

      ctrl.setContainer(WasteContainer.bag100);
      final cont = c.read(draftEstimateProvider)!;
      expect(cont.totalKg, greaterThan(count.totalKg));
      expect(cont.needsConfirmation, isFalse);

      ctrl.setManualKg('pet_bottle', 2.4);
      expect(
        c.read(draftEstimateProvider)!.lines.firstWhere((l) => l.categoryId == 'pet_bottle').kg,
        2.4,
      );
      ctrl.setManualKg('pet_bottle', null);
      expect(
        c.read(draftEstimateProvider)!.lines.firstWhere((l) => l.categoryId == 'pet_bottle').method,
        EstimationMethod.container,
      );
    });

    test('confirmed estimate is saved with a code, price scale and scan link', () async {
      final ctrl = c.read(estimateDraftControllerProvider.notifier)..confirm();
      final code = await ctrl.save();
      expect(code, hasLength(8));
      final doc = (await db.doc('estimates/$code').get()).data()!;
      expect(doc['citizenUid'], 'u');
      expect(doc['status'], 'estimated');
      expect(doc['priceScaleId'], 'default');
      expect(doc['scanId'], c.read(scanControllerProvider).scanId);
      expect(c.read(estimateDraftControllerProvider).savedCode, code);

      c.read(scanControllerProvider.notifier).reset();
      await pumpEventQueue();
      expect(
        c.read(estimateDraftControllerProvider).savedCode,
        isNull,
        reason: 'new scan resets the draft',
      );
    });
  });

  group('weighing (US-028)', () {
    const line = EstimateLine(
      categoryId: 'can',
      count: 3,
      kg: 1,
      priceDtPerKg: 4,
      method: EstimationMethod.count,
    );
    Future<String> seed() => FirestoreEstimateRepository(db).create(
      const EstimateRecord(
        code: '',
        citizenUid: 'citizen',
        lines: [line],
        confidence: .5,
        priceScaleId: 'default',
      ),
    );

    test('unverified collectors cannot weigh', () async {
      final c = await container('collector', status: 'pending');
      await c.read(weighingControllerProvider.notifier).lookup(await seed());
      expect(c.read(weighingControllerProvider).error, WeighingError.notAllowed);
    });

    test('verified collector: lookup, mandatory weights, submit once', () async {
      final c = await container('collector', status: 'approved');
      final ctrl = c.read(weighingControllerProvider.notifier);
      await ctrl.lookup('abc');
      expect(c.read(weighingControllerProvider).error, WeighingError.invalidCode);
      await ctrl.lookup('ZZZZ-ZZZZ');
      expect(c.read(weighingControllerProvider).error, WeighingError.notFound);

      final code = await seed();
      await ctrl.lookup('${code.substring(0, 4)}-${code.substring(4)}'.toLowerCase());
      expect(c.read(weighingControllerProvider).record!.code, code);
      expect(await ctrl.submit(), isFalse);
      expect(c.read(weighingControllerProvider).error, WeighingError.incomplete);

      ctrl.setActual('can', 1.25);
      expect(c.read(weighingControllerProvider).result!.finalDt, 5);
      expect(await ctrl.submit(), isTrue);
      final doc = (await db.doc('estimates/$code').get()).data()!;
      expect(doc['status'], 'weighed');
      expect(doc['finalDt'], 5);
      expect(doc['collectorUid'], 'u');

      ctrl.reset();
      await ctrl.lookup(code);
      expect(c.read(weighingControllerProvider).error, WeighingError.alreadyWeighed);
    });
  });

  test('calibration from weighed estimates (US-030)', () async {
    final c = await container('admin');
    c.listen(calibrationControllerProvider, (_, _) {});
    final repo = FirestoreEstimateRepository(db);
    const line = EstimateLine(
      categoryId: 'can',
      count: 3,
      kg: 1,
      priceDtPerKg: 4,
      method: EstimationMethod.count,
    );
    for (var i = 0; i < 3; i++) {
      final code = await repo.create(
        const EstimateRecord(
          code: '',
          citizenUid: 'x',
          lines: [line],
          confidence: .5,
          priceScaleId: 'default',
        ),
      );
      await repo.submitWeighing(code, {'can': 2}, compareWeighing([line], {'can': 2}), 'k');
    }
    final ctrl = c.read(calibrationControllerProvider.notifier);
    await ctrl.analyze();
    expect(ctrl.report!.errors.single.maeKg, 1);
    await ctrl.apply();
    await pumpEventQueue();
    expect(c.read(coefficientsProvider).value!.unitWeight('can'), closeTo(.03, 1e-9));
  });

  test('price scale publication applies to new estimates (US-027)', () async {
    final c = await container('admin');
    c.listen(priceScaleControllerProvider, (_, _) {});
    expect(c.read(activePriceScaleProvider).id, 'default');
    final current = c.read(activePriceScaleProvider);
    await c
        .read(priceScaleControllerProvider.notifier)
        .publish(
          PriceScale(
            id: '',
            effectiveFrom: DateTime(2026, 1, 1),
            pricesDtPerKg: current.pricesDtPerKg,
          ),
        );
    await pumpEventQueue();
    expect(c.read(activePriceScaleProvider).id, isNot('default'));
  });
}
