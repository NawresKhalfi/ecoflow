import 'estimate.dart';
import 'estimation_coefficients.dart';
import 'weighing.dart';

/// Erreur d'estimation par catégorie (tableau de bord MAE, US-030).
class CategoryError {
  const CategoryError({
    required this.categoryId,
    required this.samples,
    required this.maeKg,
    required this.ratio,
  });

  final String categoryId;
  final int samples;

  /// Erreur absolue moyenne, en kg.
  final double maeKg;

  /// Rapport médian réel / estimé (1 = estimation juste).
  final double ratio;
}

class CalibrationReport {
  const CalibrationReport({required this.errors, required this.proposed});

  final List<CategoryError> errors;

  /// Coefficients proposés après recalibrage.
  final EstimationCoefficients proposed;
}

double _median(List<double> v) {
  final s = [...v]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// Compare estimations et pesées réelles. Les coefficients (poids unitaire
/// pour la méthode « nombre d'objets », densité pour « contenant ») sont
/// multipliés par le rapport médian réel/estimé, borné à [0,25 ; 4], et
/// seulement à partir de [minSamples] pesées. Les saisies manuelles ne
/// recalibrent rien.
CalibrationReport calibrate(
  List<WeighingResult> weighings,
  EstimationCoefficients current, {
  int minSamples = 3,
}) {
  final byCat = <String, List<WeighingLine>>{};
  for (final w in weighings) {
    for (final l in w.lines) {
      byCat.putIfAbsent(l.categoryId, () => []).add(l);
    }
  }
  final errors = <CategoryError>[];
  final unit = {...current.unitWeightKg};
  final density = {...current.densityKgPerL};
  for (final MapEntry(key: id, value: lines) in byCat.entries) {
    final ratios = [
      for (final l in lines)
        if (l.estimatedKg > 0) l.actualKg / l.estimatedKg,
    ];
    final mae = lines.fold(0.0, (s, l) => s + l.deltaKg.abs()) / lines.length;
    final ratio = ratios.isEmpty ? 1.0 : _median(ratios);
    errors.add(CategoryError(categoryId: id, samples: lines.length, maeKg: mae, ratio: ratio));
    for (final (method, target) in [
      (EstimationMethod.count, unit),
      (EstimationMethod.container, density),
    ]) {
      final r = [
        for (final l in lines)
          if (l.estimated.method == method && l.estimatedKg > 0) l.actualKg / l.estimatedKg,
      ];
      if (r.length < minSamples) continue;
      final base = method == EstimationMethod.count ? current.unitWeight(id) : current.density(id);
      target[id] = base * _median(r).clamp(.25, 4.0);
    }
  }
  errors.sort((a, b) => b.maeKg.compareTo(a.maeKg));
  return CalibrationReport(
    errors: errors,
    proposed: EstimationCoefficients(
      unitWeightKg: unit,
      densityKgPerL: density,
      version: current.version + 1,
    ),
  );
}
