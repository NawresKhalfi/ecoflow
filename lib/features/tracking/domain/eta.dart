import '../../collection/domain/geo.dart';

/// Position diffusée par le collecteur pendant la mission (US-063).
class LivePosition {
  const LivePosition({required this.point, required this.at, this.speedKmh});
  final GeoPoint point;
  final DateTime at;

  /// Vitesse mesurée par le GPS, si disponible.
  final double? speedKmh;
}

/// Intervalle d'envoi de la position (US-063 : 5 à 10 s).
const liveUpdateInterval = Duration(seconds: 5);

/// Position trop ancienne : le collecteur a perdu le réseau ou fermé l'app.
const staleAfter = Duration(seconds: 45);

bool isStale(LivePosition p, DateTime now) => now.difference(p.at) > staleAfter;

/// Congestion urbaine selon l'heure (heures de pointe tunisiennes).
/// Faute d'API de trafic, c'est un modèle horaire (US-064).
double trafficFactor(DateTime at) {
  final h = at.hour + at.minute / 60;
  if ((h >= 7 && h < 9) || (h >= 17 && h < 19.5)) return 1.6;
  if (h >= 12 && h < 14) return 1.25;
  return 1.0;
}

/// Heure d'arrivée estimée : distance routière restante / vitesse, la
/// vitesse étant celle mesurée si plausible, sinon la vitesse urbaine de
/// référence ralentie par le trafic.
DateTime estimateArrival({
  required LivePosition from,
  required GeoPoint to,
  required DateTime now,
  double roadFactor = 1.3,
  double baseSpeedKmh = 25,
}) {
  final km = distanceKm(from.point, to) * roadFactor;
  final measured = from.speedKmh;
  final speed = measured != null && measured >= 8 && measured <= 90
      ? measured
      : baseSpeedKmh / trafficFactor(now);
  return now.add(Duration(seconds: (km / speed * 3600).round()));
}
