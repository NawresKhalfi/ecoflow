import '../../collection/domain/geo.dart';

/// Arrêt à visiter : une collecte avec sa fenêtre horaire et son poids.
class Stop {
  const Stop({
    required this.id,
    required this.point,
    required this.kg,
    required this.windowStart,
    required this.windowEnd,
    this.label = '',
  });

  final String id;
  final GeoPoint point;
  final double kg;
  final DateTime windowStart;
  final DateTime windowEnd;
  final String label;
}

enum VisitKind { pickup, unload }

/// Passage planifié : collecte, ou déchargement au dépôt (capacité).
class Visit {
  const Visit({
    required this.kind,
    required this.point,
    required this.arrival,
    required this.departure,
    required this.loadAfterKg,
    this.stop,
    this.waitMinutes = 0,
  });

  final VisitKind kind;
  final Stop? stop;
  final GeoPoint point;
  final DateTime arrival;
  final DateTime departure;
  final double loadAfterKg;
  final double waitMinutes;
}

/// Tournée évaluée.
class Tour {
  const Tour({
    required this.visits,
    required this.distanceKm,
    required this.durationMinutes,
    required this.waitMinutes,
    required this.unassigned,
  });

  final List<Visit> visits;
  final double distanceKm;
  final double durationMinutes;
  final double waitMinutes;

  /// Collectes impossibles à servir dans leur créneau.
  final List<Stop> unassigned;

  /// Temps actif : trajets et collectes, hors attentes entre créneaux.
  double get activeMinutes => durationMinutes - waitMinutes;

  List<Stop> get order => [
    for (final v in visits)
      if (v.stop != null) v.stop!,
  ];
}

/// Économies de l'ordre optimisé face à l'ordre naïf (US-057, US-060).
class Savings {
  const Savings({
    required this.km,
    required this.minutes,
    required this.fuelL,
    required this.co2Kg,
    required this.dt,
  });

  final double km;
  final double minutes;
  final double fuelL;
  final double co2Kg;
  final double dt;

  bool get isPositive => km > .05;
}
