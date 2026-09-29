import 'detection.dart';

/// Résumé des corrections apportées par l'utilisateur (US-016), conservé
/// pour réentraîner le modèle (US-020).
class CorrectionSummary {
  const CorrectionSummary({this.added = 0, this.removed = 0, this.relabelled = 0});

  final int added;
  final int removed;
  final int relabelled;

  bool get hasChanges => added + removed + relabelled > 0;

  Map<String, int> toMap() => {'added': added, 'removed': removed, 'relabelled': relabelled};
}

CorrectionSummary summarizeCorrections(List<Detection> original, List<Detection> corrected) {
  final ids = {for (final d in corrected) d.id};
  final originalIds = {for (final d in original) d.id};
  return CorrectionSummary(
    added: corrected.where((d) => !originalIds.contains(d.id)).length,
    removed: original.where((d) => !ids.contains(d.id)).length,
    relabelled: corrected.where((d) => d.isRelabelled).length,
  );
}
