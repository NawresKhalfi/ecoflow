import 'detection.dart';
import 'waste_category.dart';

/// Limites d'import (US-012).
const maxPhotosPerScan = 5;
const allowedImageExtensions = {'jpg', 'jpeg', 'png'};

bool isAllowedImage(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot > 0 && allowedImageExtensions.contains(fileName.substring(dot + 1).toLowerCase());
}

/// Seuil de confiance par défaut (configurable par l'admin et l'utilisateur).
const defaultConfidenceThreshold = .35;

/// Seuil minimal conservé à l'inférence, pour pouvoir baisser le curseur
/// d'affichage sans relancer l'analyse.
const inferenceFloor = .10;

/// Convertit les sorties brutes du modèle en détections du catalogue.
List<Detection> toDetections(
  List<RawDetection> raw,
  List<WasteCategory> catalog, {
  required int photoIndex,
}) => [
  for (final (i, r) in raw.indexed)
    Detection(
      id: 'p$photoIndex-d$i',
      photoIndex: photoIndex,
      categoryId: categoryForLabel(catalog, r.label),
      confidence: r.confidence,
      box: r.box,
      rawLabel: r.label,
    ),
];

/// Détections visibles pour un seuil donné (les ajouts manuels restent).
List<Detection> visibleDetections(List<Detection> all, double threshold) => [
  for (final d in all)
    if (d.source == DetectionSource.manual || d.confidence >= threshold) d,
];

/// Nombre d'objets par catégorie (US-014), trié par ordre du catalogue.
Map<String, int> countByCategory(List<Detection> detections, List<WasteCategory> catalog) {
  final counts = <String, int>{};
  for (final d in detections) {
    counts[d.categoryId] = (counts[d.categoryId] ?? 0) + 1;
  }
  int order(String id) => catalog.where((c) => c.id == id).firstOrNull?.order ?? 999;
  final keys = counts.keys.toList()..sort((a, b) => order(a).compareTo(order(b)));
  return {for (final k in keys) k: counts[k]!};
}

/// Recyclabilité estimée d'un scan (US-015) et catégories déterminantes.
class RecyclabilityEstimate {
  const RecyclabilityEstimate(this.level, this.score, this.drivers);

  final Recyclability level;
  final double score;

  /// Catégories les plus représentées, pour l'explication affichée.
  final List<String> drivers;
}

RecyclabilityEstimate? estimateRecyclability(
  List<Detection> detections,
  List<WasteCategory> catalog,
) {
  if (detections.isEmpty) return null;
  Recyclability of(String id) =>
      catalog.where((c) => c.id == id).firstOrNull?.recyclability ?? Recyclability.low;
  final score =
      detections.map((d) => of(d.categoryId).score).reduce((a, b) => a + b) / detections.length;
  final level = score >= .7
      ? Recyclability.high
      : score >= .4
      ? Recyclability.medium
      : Recyclability.low;
  final counts = countByCategory(detections, catalog).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return RecyclabilityEstimate(level, score, counts.take(2).map((e) => e.key).toList());
}

/// Indice de confiance global : moyenne des scores des objets détectés.
double? averageConfidence(List<Detection> detections) {
  final model = detections.where((d) => d.source == DetectionSource.model).toList();
  if (model.isEmpty) return null;
  return model.map((d) => d.confidence).reduce((a, b) => a + b) / model.length;
}
