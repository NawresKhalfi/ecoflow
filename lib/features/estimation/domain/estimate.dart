import '../../scan/domain/detection.dart';
import '../../scan/domain/scan_rules.dart';
import '../../scan/domain/waste_category.dart';
import 'estimation_coefficients.dart';
import 'price_scale.dart';

/// Méthode d'estimation, de la plus fiable à la moins fiable.
enum EstimationMethod {
  manual(1),
  container(.8),
  count(.55);

  const EstimationMethod(this.reliability);

  /// Facteur multiplicatif de l'indice de confiance (US-025).
  final double reliability;

  static EstimationMethod fromName(String? n) =>
      values.firstWhere((v) => v.name == n, orElse: () => EstimationMethod.count);
}

/// En dessous de ce seuil, on invite à confirmer ou saisir le poids.
const confirmationThreshold = .6;

/// Estimation pour une catégorie.
class EstimateLine {
  const EstimateLine({
    required this.categoryId,
    required this.count,
    required this.kg,
    required this.priceDtPerKg,
    required this.method,
  });

  final String categoryId;
  final int count;
  final double kg;
  final double priceDtPerKg;
  final EstimationMethod method;

  double get valueDt => kg * priceDtPerKg;

  Map<String, dynamic> toMap() => {
    'category': categoryId,
    'count': count,
    'kg': kg,
    'price': priceDtPerKg,
    'method': method.name,
  };

  static EstimateLine fromMap(Map m) => EstimateLine(
    categoryId: m['category'] as String,
    count: (m['count'] as num?)?.toInt() ?? 0,
    kg: (m['kg'] as num).toDouble(),
    priceDtPerKg: (m['price'] as num).toDouble(),
    method: EstimationMethod.fromName(m['method'] as String?),
  );
}

/// Estimation complète d'un scan (US-023, US-024, US-025).
class Estimate {
  const Estimate({required this.lines, required this.confidence, required this.priceScaleId});

  final List<EstimateLine> lines;

  /// Indice de confiance 0..1.
  final double confidence;
  final String priceScaleId;

  double get totalKg => lines.fold(0, (s, l) => s + l.kg);
  double get totalDt => lines.fold(0, (s, l) => s + l.valueDt);
  bool get needsConfirmation => confidence < confirmationThreshold;
  bool get isEmpty => lines.isEmpty;
}

/// Calcule l'estimation. Priorité par catégorie : poids saisi à la main,
/// puis contenant (volume utile réparti au prorata du nombre d'objets ×
/// densité), sinon nombre d'objets × poids unitaire.
Estimate estimateScan({
  required List<Detection> detections,
  required List<WasteCategory> catalog,
  required PriceScale prices,
  required EstimationCoefficients coefficients,
  WasteContainer? container,
  Map<String, double> manualKg = const {},
}) {
  final counts = countByCategory(detections, catalog);
  final ids = {...counts.keys, ...manualKg.keys.where((k) => (manualKg[k] ?? 0) > 0)};
  final totalCount = counts.values.fold(0, (a, b) => a + b);
  WasteCategory cat(String id) =>
      catalog.where((c) => c.id == id).firstOrNull ??
      defaultCatalog.firstWhere((c) => c.id == otherCategoryId);

  final lines = <EstimateLine>[];
  for (final id in ids) {
    final count = counts[id] ?? 0;
    final manual = manualKg[id];
    final (kg, method) = switch (manual) {
      final m? when m > 0 => (m, EstimationMethod.manual),
      _ when container != null && totalCount > 0 => (
        container.usefulLiters * count / totalCount * coefficients.density(id),
        EstimationMethod.container,
      ),
      _ => (count * coefficients.unitWeight(id), EstimationMethod.count),
    };
    lines.add(
      EstimateLine(
        categoryId: id,
        count: count,
        kg: kg,
        priceDtPerKg: prices.priceOf(cat(id).material),
        method: method,
      ),
    );
  }

  // Confiance = qualité de la détection × fiabilité de la méthode,
  // pondérée par le poids de chaque ligne.
  final detectionConfidence = averageConfidence(detections) ?? 1;
  final totalKg = lines.fold(0.0, (s, l) => s + l.kg);
  final confidence = totalKg == 0
      ? 0.0
      : lines.fold(0.0, (s, l) {
          final det = l.method == EstimationMethod.manual ? 1.0 : detectionConfidence;
          return s + l.kg / totalKg * det * l.method.reliability;
        });
  return Estimate(lines: lines, confidence: confidence, priceScaleId: prices.id);
}
