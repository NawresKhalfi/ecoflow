import '../../collection/domain/geo.dart';

/// Zone de travail du collecteur : un rayon autour d'un centre (US-042).
class WorkZone {
  const WorkZone({required this.center, required this.radiusKm});

  final GeoPoint center;
  final double radiusKm;

  bool contains(GeoPoint p) => distanceKm(center, p) <= radiusKm;

  Map<String, dynamic> toMap() => {'center': center.toMap(), 'radiusKm': radiusKm};

  static WorkZone? fromMap(Object? m) {
    if (m is! Map) return null;
    final c = GeoPoint.fromMap(m['center']);
    return c == null
        ? null
        : WorkZone(center: c, radiusKm: (m['radiusKm'] as num?)?.toDouble() ?? 10);
  }
}

/// Rayons proposés.
const workZoneRadiiKm = [3.0, 5.0, 10.0, 20.0, 40.0];
