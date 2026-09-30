import '../../collection/domain/geo.dart';
import 'tour.dart';

/// Groupe de collectes proches, servables dans une même tournée (US-056).
class StopCluster {
  const StopCluster(this.stops);
  final List<Stop> stops;

  double get totalKg => stops.fold(0, (s, x) => s + x.kg);

  GeoPoint get center => GeoPoint(
    stops.fold(0.0, (s, x) => s + x.point.lat) / stops.length,
    stops.fold(0.0, (s, x) => s + x.point.lng) / stops.length,
  );
}

/// Regroupement glouton par densité : on part de l'arrêt ayant le plus de
/// voisins dans [radiusKm], on agrège ses voisins (les plus proches
/// d'abord) tant que la capacité le permet, puis on recommence.
List<StopCluster> clusterStops(
  List<Stop> stops, {
  required double radiusKm,
  required double capacityKg,
  int maxPerCluster = 8,
}) {
  final remaining = [...stops];
  final clusters = <StopCluster>[];
  while (remaining.isNotEmpty) {
    int neighbours(Stop s) =>
        remaining.where((o) => distanceKm(s.point, o.point) <= radiusKm).length;
    remaining.sort((a, b) => neighbours(b).compareTo(neighbours(a)));
    final seed = remaining.first;
    final near = remaining.where((o) => distanceKm(seed.point, o.point) <= radiusKm).toList()
      ..sort((a, b) => distanceKm(seed.point, a.point).compareTo(distanceKm(seed.point, b.point)));
    final group = <Stop>[];
    var kg = 0.0;
    for (final s in near) {
      if (group.length >= maxPerCluster || kg + s.kg > capacityKg) continue;
      group.add(s);
      kg += s.kg;
    }
    if (group.isEmpty) group.add(seed); // arrêt plus lourd que la capacité : seul
    clusters.add(StopCluster(group));
    remaining.removeWhere(group.contains);
  }
  clusters.sort((a, b) => b.stops.length.compareTo(a.stops.length));
  return clusters;
}
