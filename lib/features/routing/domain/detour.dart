import '../../collection/domain/geo.dart';
import 'route_solver.dart';
import 'tour.dart';

/// Mission compatible avec le trajet en cours (US-061).
class DetourSuggestion {
  const DetourSuggestion({required this.stop, required this.extraKm, required this.position});
  final Stop stop;
  final double extraKm;

  /// Rang d'insertion dans l'ordre actuel.
  final int position;
}

/// Pour chaque candidat, meilleure insertion faisable (créneaux, capacité)
/// dans la tournée ; gardés si le détour ≤ [maxDetourKm], triés par détour.
List<DetourSuggestion> detourSuggestions(
  RouteSolver solver,
  List<Stop> current,
  List<Stop> candidates, {
  required GeoPoint start,
  required DateTime startAt,
  required double capacityKg,
  required double maxDetourKm,
}) {
  final base = solver.evaluate(current, start: start, startAt: startAt, capacityKg: capacityKg);
  if (base == null) return const [];
  final result = <DetourSuggestion>[];
  for (final c in candidates) {
    DetourSuggestion? best;
    for (var i = 0; i <= current.length; i++) {
      final t = solver.evaluate(
        [...current]..insert(i, c),
        start: start,
        startAt: startAt,
        capacityKg: capacityKg,
      );
      if (t == null) continue;
      final extra = t.distanceKm - base.distanceKm;
      if (best == null || extra < best.extraKm) {
        best = DetourSuggestion(stop: c, extraKm: extra, position: i);
      }
    }
    if (best != null && best.extraKm <= maxDetourKm) result.add(best);
  }
  result.sort((a, b) => a.extraKm.compareTo(b.extraKm));
  return result;
}
