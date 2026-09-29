import 'dart:math';

/// Point géographique (degrés décimaux).
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// Position arrondie (≈ 1 km avec 2 décimales) pour la vie privée.
  GeoPoint rounded([int decimals = 2]) {
    final f = pow(10, decimals);
    return GeoPoint((lat * f).round() / f, (lng * f).round() / f);
  }

  Map<String, double> toMap() => {'lat': lat, 'lng': lng};

  static GeoPoint? fromMap(Object? m) => m is Map && m['lat'] is num && m['lng'] is num
      ? GeoPoint((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble())
      : null;

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// Distance orthodromique (formule de haversine), en km.
double distanceKm(GeoPoint a, GeoPoint b) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(b.lat - a.lat);
  final dLng = rad(b.lng - a.lng);
  final h =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(a.lat)) * cos(rad(b.lat)) * sin(dLng / 2) * sin(dLng / 2);
  return 2 * r * asin(sqrt(h));
}
