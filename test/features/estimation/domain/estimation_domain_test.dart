import 'dart:math';

import 'package:ecoflow/features/estimation/domain/calibration.dart';
import 'package:ecoflow/features/estimation/domain/estimate.dart';
import 'package:ecoflow/features/estimation/domain/estimation_coefficients.dart';
import 'package:ecoflow/features/estimation/domain/handover_code.dart';
import 'package:ecoflow/features/estimation/domain/price_scale.dart';
import 'package:ecoflow/features/estimation/domain/weighing.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:ecoflow/features/scan/domain/detection.dart';
import 'package:ecoflow/features/scan/domain/waste_category.dart';
import 'package:flutter_test/flutter_test.dart';

Detection det(String cat, [double conf = .9, int i = 0]) =>
    Detection(id: '$cat$i', photoIndex: 0, categoryId: cat, confidence: conf);

void main() {
  final prices = PriceScale(
    id: 's1',
    effectiveFrom: DateTime(2026, 9),
    pricesDtPerKg: const {RecyclableMaterial.pet: 1.5, RecyclableMaterial.aluminium: 4},
  );

  group('price scale (US-027)', () {
    PriceScale s(String id, DateTime from, [DateTime? created]) =>
        PriceScale(id: id, effectiveFrom: from, pricesDtPerKg: const {}, createdAt: created);

    test('latest effective scale at the request date, future ones ignored', () {
      final scales = [
        s('jan', DateTime(2026, 1)),
        s('jun', DateTime(2026, 6)),
        s('dec', DateTime(2026, 12)),
      ];
      expect(activeScaleAt(scales, DateTime(2026, 9)).id, 'jun');
      expect(activeScaleAt(scales, DateTime(2026, 12, 2)).id, 'dec');
      expect(activeScaleAt(scales, DateTime(2025)).id, 'default');
      expect(activeScaleAt(const [], DateTime(2026)).id, 'default');
    });

    test('same effective date: last published wins', () {
      final d = DateTime(2026, 6);
      final scales = [s('a', d, DateTime(2026, 5, 1)), s('b', d, DateTime(2026, 5, 2))];
      expect(activeScaleAt(scales, DateTime(2026, 7)).id, 'b');
    });

    test('round-trip', () {
      final back = PriceScale.fromMap('x', prices.toMap(), effectiveFrom: prices.effectiveFrom);
      expect(back.priceOf(RecyclableMaterial.pet), 1.5);
      expect(back.priceOf(null), 0);
    });
  });

  group('estimation (US-023/024/025/026)', () {
    Estimate run(List<Detection> d, {WasteContainer? c, Map<String, double> manual = const {}}) =>
        estimateScan(
          detections: d,
          catalog: defaultCatalog,
          prices: prices,
          coefficients: defaultCoefficients,
          container: c,
          manualKg: manual,
        );

    test('count method: objects × unit weight, low confidence asks confirmation', () {
      final e = run([det('pet_bottle', .9, 1), det('pet_bottle', .9, 2), det('can', .9)]);
      final pet = e.lines.firstWhere((l) => l.categoryId == 'pet_bottle');
      expect(pet.kg, closeTo(.06, 1e-9));
      expect(pet.valueDt, closeTo(.09, 1e-9));
      expect(pet.method, EstimationMethod.count);
      expect(e.confidence, closeTo(.9 * .55, 1e-9));
      expect(e.needsConfirmation, isTrue);
      expect(e.priceScaleId, 's1');
    });

    test('container method: useful volume split by count × density', () {
      final e = run([det('pet_bottle'), det('can')], c: WasteContainer.bag50);
      final pet = e.lines.firstWhere((l) => l.categoryId == 'pet_bottle');
      expect(pet.kg, closeTo(50 * .8 / 2 * .02, 1e-9));
      expect(pet.method, EstimationMethod.container);
      expect(e.confidence, closeTo(.9 * .8, 1e-9));
      expect(e.needsConfirmation, isFalse);
    });

    test('manual weight wins and gives full confidence; manual-only categories appear', () {
      final e = run([det('pet_bottle')], manual: {'pet_bottle': 2.4, 'glass': 1.0});
      expect(e.totalKg, closeTo(3.4, 1e-9));
      expect(e.lines.firstWhere((l) => l.categoryId == 'pet_bottle').valueDt, closeTo(3.6, 1e-9));
      expect(
        e.lines.firstWhere((l) => l.categoryId == 'glass').valueDt,
        0,
        reason: 'glass price not in scale',
      );
      expect(e.confidence, closeTo(1, 1e-9));
    });

    test('no detection → empty estimate', () {
      expect(run(const []).isEmpty, isTrue);
    });
  });

  group('weighing (US-028/029)', () {
    const lines = [
      EstimateLine(
        categoryId: 'pet_bottle',
        count: 2,
        kg: 2,
        priceDtPerKg: 1.5,
        method: EstimationMethod.container,
      ),
      EstimateLine(
        categoryId: 'can',
        count: 1,
        kg: 1,
        priceDtPerKg: 4,
        method: EstimationMethod.container,
      ),
    ];

    test('real weight mandatory for each material (0 allowed)', () {
      expect(isWeighingComplete(lines, {'pet_bottle': 2.1}), isFalse);
      expect(isWeighingComplete(lines, {'pet_bottle': 2.1, 'can': 0}), isTrue);
      expect(isWeighingComplete(lines, {'pet_bottle': 2.1, 'can': null}), isFalse);
    });

    test('final value uses the estimate price scale; gaps per material', () {
      final r = compareWeighing(lines, {'pet_bottle': 2.5, 'can': .5});
      expect(r.finalDt, closeTo(2.5 * 1.5 + .5 * 4, 1e-9));
      expect(r.estimatedDt, closeTo(7, 1e-9));
      expect(r.deltaDt, closeTo(-1.25, 1e-9));
      expect(r.lines.first.deltaRatio, closeTo(.25, 1e-9));
      expect(r.lines.last.deltaKg, closeTo(-.5, 1e-9));
    });
  });

  group('calibration (US-030)', () {
    WeighingResult w(double est, double real, EstimationMethod m) => compareWeighing(
      [EstimateLine(categoryId: 'can', count: 10, kg: est, priceDtPerKg: 4, method: m)],
      {'can': real},
    );

    test('MAE per category and coefficients scaled by median ratio', () {
      final report = calibrate([
        w(1, 2, EstimationMethod.count),
        w(1, 2, EstimationMethod.count),
        w(1, 2.2, EstimationMethod.count),
        w(1, 1.2, EstimationMethod.container),
      ], defaultCoefficients);
      final e = report.errors.single;
      expect(e.samples, 4);
      expect(e.maeKg, closeTo((1 + 1 + 1.2 + .2) / 4, 1e-9));
      expect(report.proposed.unitWeight('can'), closeTo(.015 * 2, 1e-9));
      expect(report.proposed.density('can'), .035, reason: 'only 1 container sample < minSamples');
      expect(report.proposed.version, 2);
    });

    test('ratio is clamped and manual entries never recalibrate', () {
      final r = calibrate([
        for (var i = 0; i < 3; i++) w(1, 100, EstimationMethod.count),
      ], defaultCoefficients);
      expect(r.proposed.unitWeight('can'), closeTo(.015 * 4, 1e-9));
      final m = calibrate([
        for (var i = 0; i < 3; i++) w(1, 3, EstimationMethod.manual),
      ], defaultCoefficients);
      expect(m.proposed.unitWeight('can'), .015);
    });
  });

  group('handover code', () {
    test('8 unambiguous characters, formatted and normalized', () {
      final c = generateHandoverCode(Random(1));
      expect(c, hasLength(8));
      expect(c, isNot(matches(RegExp('[01OIL]'))));
      expect(formatHandoverCode(c), '${c.substring(0, 4)}-${c.substring(4)}');
      expect(normalizeHandoverCode(' ${formatHandoverCode(c).toLowerCase()} '), c);
      expect(normalizeHandoverCode('ABC'), isNull);
      expect(normalizeHandoverCode('ABCD-EF0O'), isNull);
    });
  });

  test('coefficients round-trip keeps defaults for missing entries', () {
    final c = EstimationCoefficients.fromMap({
      'unitWeightKg': {'can': .02},
      'version': 3,
    });
    expect(c.unitWeight('can'), .02);
    expect(c.unitWeight('pet_bottle'), .03);
    expect(c.version, 3);
    expect(EstimationCoefficients.fromMap(null).version, 1);
  });
}
