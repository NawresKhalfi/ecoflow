import 'package:ecoflow/features/estimation/data/estimation_repositories.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimate_record.dart';
import 'package:ecoflow/features/estimation/domain/estimation_coefficients.dart';
import 'package:ecoflow/features/estimation/domain/price_scale.dart';
import 'package:ecoflow/features/estimation/domain/weighing.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

const line = EstimateLine(
  categoryId: 'can',
  count: 3,
  kg: 1,
  priceDtPerKg: 4,
  method: EstimationMethod.container,
);

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  test('price scales are published with history, newest first', () async {
    final repo = FirestorePriceScaleRepository(db);
    for (final m in [1, 6]) {
      await repo.publish(
        PriceScale(
          id: '',
          effectiveFrom: DateTime(2026, m),
          pricesDtPerKg: {RecyclableMaterial.pet: m.toDouble()},
        ),
      );
    }
    final list = await repo.watch().first;
    expect(list.map((s) => s.effectiveFrom.month), [6, 1]);
    expect(list.first.priceOf(RecyclableMaterial.pet), 6);
  });

  test('coefficients keep the previous version', () async {
    final repo = FirestoreCoefficientsRepository(db);
    expect((await repo.watch().first).version, 1);
    const next = EstimationCoefficients(unitWeightKg: {'can': .02}, densityKgPerL: {}, version: 2);
    await repo.save(next, defaultCoefficients);
    expect((await repo.watch().first).unitWeight('can'), .02);
    expect((await db.doc('config/estimation').get()).data()!['previous']['version'], 1);
  });

  test('estimate lifecycle: create under a unique code, weigh once', () async {
    final codes = ['AAAAAAAA', 'AAAAAAAA', 'BBBBBBBB'];
    final repo = FirestoreEstimateRepository(db, codeGenerator: () => codes.removeAt(0));
    const record = EstimateRecord(
      code: '',
      citizenUid: 'u',
      lines: [line],
      confidence: .7,
      priceScaleId: 'default',
    );
    expect(await repo.create(record), 'AAAAAAAA');
    expect(await repo.create(record), 'BBBBBBBB', reason: 'collision retried');

    final mine = await repo.watchMine('u').first;
    expect(mine, hasLength(2));
    expect((await repo.fetch('AAAAAAAA'))!.estimate.totalDt, 4);
    expect(await repo.fetch('ZZZZZZZZ'), isNull);

    final actual = {'can': 1.5};
    await repo.submitWeighing('AAAAAAAA', actual, compareWeighing([line], actual), 'collector1');
    final weighed = (await repo.fetch('AAAAAAAA'))!;
    expect(weighed.isWeighed, isTrue);
    expect(weighed.weighing!.finalDt, 6);
    expect(weighed.collectorUid, 'collector1');
    expect((await repo.weighed()).map((r) => r.code), ['AAAAAAAA']);
  });
}
