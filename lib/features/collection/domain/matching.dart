import 'geo.dart';

/// Collecteur disponible (`collectorPresence/{uid}`, position arrondie).
class CollectorCandidate {
  const CollectorCandidate({
    required this.uid,
    required this.point,
    required this.capacityKg,
    this.rating = 0,
    this.ratingCount = 0,
    this.online = true,
  });

  final String uid;
  final GeoPoint point;
  final double capacityKg;
  final double rating;
  final int ratingCount;
  final bool online;
}

class MatchResult {
  const MatchResult(this.candidate, this.radiusKm, this.distanceKm);

  final CollectorCandidate? candidate;

  /// Rayon auquel un collecteur a été trouvé (ou le dernier essayé).
  final double radiusKm;
  final double? distanceKm;

  bool get found => candidate != null;
}

/// Rayons successifs : 5 km puis élargissement progressif (US-034).
const searchRadiiKm = [5.0, 10.0, 20.0];

/// Note par défaut d'un collecteur sans avis (neutre).
const _neutralRating = 3.5;

/// Score (plus haut = meilleur) : proximité 60 %, note 30 %, marge de
/// capacité 10 %.
double collectorScore(CollectorCandidate c, double distance, double radius, double neededKg) {
  final proximity = 1 - (distance / radius).clamp(0, 1);
  final rating = (c.ratingCount == 0 ? _neutralRating : c.rating) / 5;
  final margin = c.capacityKg <= 0
      ? 0.0
      : ((c.capacityKg - neededKg) / c.capacityKg).clamp(0, 1).toDouble();
  return .6 * proximity + .3 * rating + .1 * margin;
}

/// Cherche le meilleur collecteur en ligne, de capacité suffisante, non
/// exclu, dans un rayon croissant.
MatchResult matchCollector({
  required GeoPoint pickup,
  required double neededKg,
  required List<CollectorCandidate> candidates,
  Set<String> excluded = const {},
  List<double> radii = searchRadiiKm,
}) {
  final eligible = [
    for (final c in candidates)
      if (c.online && !excluded.contains(c.uid) && c.capacityKg >= neededKg)
        (c, distanceKm(pickup, c.point)),
  ];
  for (final r in radii) {
    final inRange = eligible.where((e) => e.$2 <= r).toList()
      ..sort(
        (a, b) => collectorScore(
          b.$1,
          b.$2,
          r,
          neededKg,
        ).compareTo(collectorScore(a.$1, a.$2, r, neededKg)),
      );
    if (inRange.isNotEmpty) return MatchResult(inRange.first.$1, r, inRange.first.$2);
  }
  return MatchResult(null, radii.last, null);
}
