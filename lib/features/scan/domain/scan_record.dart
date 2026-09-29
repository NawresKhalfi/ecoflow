import 'detection.dart';
import 'scan_correction.dart';

/// Durée de conservation des photos de scan (US-021).
const photoRetention = Duration(days: 90);

/// Scan enregistré : `scans/{id}` (photos dans `scans/{id}/photos/{i}`).
class ScanRecord {
  const ScanRecord({
    required this.id,
    required this.uid,
    required this.photoCount,
    required this.detections,
    required this.originalDetections,
    required this.modelVersionId,
    required this.threshold,
    this.inferenceMs,
    this.trainingConsent = false,
    this.createdAt,
  });

  final String id;
  final String uid;
  final int photoCount;

  /// Résultat final (après corrections éventuelles).
  final List<Detection> detections;

  /// Proposition initiale de l'IA.
  final List<Detection> originalDetections;
  final String modelVersionId;
  final double threshold;
  final int? inferenceMs;

  /// L'utilisateur accepte que ses photos corrigées servent à l'entraînement.
  final bool trainingConsent;
  final DateTime? createdAt;

  CorrectionSummary get corrections => summarizeCorrections(originalDetections, detections);
}
