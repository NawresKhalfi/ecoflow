import 'estimate.dart';

/// Écart estimation / pesée réelle pour une catégorie (US-028, US-029).
class WeighingLine {
  const WeighingLine({required this.estimated, required this.actualKg});

  final EstimateLine estimated;
  final double actualKg;

  String get categoryId => estimated.categoryId;
  double get estimatedKg => estimated.kg;
  double get deltaKg => actualKg - estimatedKg;

  /// Écart relatif ; `null` si rien n'était estimé.
  double? get deltaRatio => estimatedKg == 0 ? null : deltaKg / estimatedKg;

  /// Valeur finale : même barème que l'estimation (celui de la demande).
  double get finalDt => actualKg * estimated.priceDtPerKg;
  double get estimatedDt => estimated.valueDt;
}

/// Pesée complète.
class WeighingResult {
  const WeighingResult(this.lines);

  final List<WeighingLine> lines;

  double get actualKg => lines.fold(0, (s, l) => s + l.actualKg);
  double get estimatedKg => lines.fold(0, (s, l) => s + l.estimatedKg);
  double get finalDt => lines.fold(0, (s, l) => s + l.finalDt);
  double get estimatedDt => lines.fold(0, (s, l) => s + l.estimatedDt);
  double get deltaDt => finalDt - estimatedDt;
}

/// Le poids réel est obligatoire pour chaque catégorie (0 accepté si absente).
bool isWeighingComplete(List<EstimateLine> lines, Map<String, double?> actual) =>
    lines.every((l) => (actual[l.categoryId] ?? -1) >= 0);

WeighingResult compareWeighing(List<EstimateLine> lines, Map<String, double> actualKg) =>
    WeighingResult([
      for (final l in lines) WeighingLine(estimated: l, actualKg: actualKg[l.categoryId] ?? 0),
    ]);
