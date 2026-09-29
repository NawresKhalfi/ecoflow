import 'geo.dart';

/// Zone desservie (cercle). La gestion admin des zones (polygones,
/// activation) arrive avec l'US-117 ; `config/collection` peut déjà les
/// surcharger.
class ServiceZone {
  const ServiceZone({
    required this.id,
    required this.name,
    required this.center,
    required this.radiusKm,
    this.active = true,
  });

  final String id;
  final String name;
  final GeoPoint center;
  final double radiusKm;
  final bool active;

  bool contains(GeoPoint p) => active && distanceKm(center, p) <= radiusKm;

  Map<String, dynamic> toMap() => {
    'name': name,
    'center': center.toMap(),
    'radiusKm': radiusKm,
    'active': active,
  };

  static ServiceZone? fromMap(String id, Map m) {
    final c = GeoPoint.fromMap(m['center']);
    if (c == null) return null;
    return ServiceZone(
      id: id,
      name: m['name'] as String? ?? id,
      center: c,
      radiusKm: (m['radiusKm'] as num?)?.toDouble() ?? 10,
      active: m['active'] as bool? ?? true,
    );
  }
}

/// Zones de lancement par défaut (centres-villes, rayons indicatifs).
const defaultZones = [
  ServiceZone(id: 'tunis', name: 'Grand Tunis', center: GeoPoint(36.8065, 10.1815), radiusKm: 25),
  ServiceZone(id: 'sousse', name: 'Sousse', center: GeoPoint(35.8256, 10.6084), radiusKm: 15),
  ServiceZone(id: 'monastir', name: 'Monastir', center: GeoPoint(35.7643, 10.8113), radiusKm: 10),
  ServiceZone(id: 'sfax', name: 'Sfax', center: GeoPoint(34.7406, 10.7603), radiusKm: 15),
  ServiceZone(id: 'nabeul', name: 'Nabeul', center: GeoPoint(36.4561, 10.7376), radiusKm: 12),
];

/// Zone desservie contenant le point (la plus proche si plusieurs).
ServiceZone? zoneFor(GeoPoint p, List<ServiceZone> zones) {
  ServiceZone? best;
  for (final z in zones.where((z) => z.contains(p))) {
    if (best == null || distanceKm(z.center, p) < distanceKm(best.center, p)) best = z;
  }
  return best;
}
