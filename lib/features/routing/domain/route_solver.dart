import '../../collection/domain/geo.dart';
import 'optimization_config.dart';
import 'tour.dart';

/// Solveur de tournée pour un collecteur (problème de tournée avec
/// capacité et fenêtres horaires, CVRPTW à un véhicule) :
///  1. construction par insertion au moindre coût, en respectant les
///     créneaux (arrivée ≤ fin du créneau ; attente si en avance) ;
///  2. recherche locale (2-opt et or-opt) depuis le meilleur de la
///     construction et de l'ordre naïf : jamais pire que ce dernier ;
///  3. capacité : quand la charge dépasserait la capacité, un retour de
///     déchargement au dépôt est inséré automatiquement (US-058).
/// Taille visée : une journée de collecteur (≤ 30 arrêts) — O(n³), quelques
/// millisecondes sur téléphone.
class RouteSolver {
  const RouteSolver(this.config);

  final OptimizationConfig config;

  double roadKm(GeoPoint a, GeoPoint b) => distanceKm(a, b) * config.roadFactor;
  double _travelMin(GeoPoint a, GeoPoint b) => roadKm(a, b) / config.speedKmh * 60;

  /// Simule un ordre donné. Renvoie `null` si un créneau est dépassé ou si
  /// un arrêt seul excède la capacité.
  Tour? evaluate(
    List<Stop> order, {
    required GeoPoint start,
    required DateTime startAt,
    required double capacityKg,
    GeoPoint? depot,
  }) {
    final unload = depot ?? start;
    var pos = start;
    var time = startAt;
    var load = 0.0;
    var km = 0.0;
    var wait = 0.0;
    final visits = <Visit>[];
    for (final s in order) {
      if (s.kg > capacityKg + 1e-9) return null;
      if (load + s.kg > capacityKg + 1e-9) {
        km += roadKm(pos, unload);
        time = time.add(_minutes(_travelMin(pos, unload)));
        final leave = time.add(_minutes(config.serviceMinutes));
        visits.add(
          Visit(
            kind: VisitKind.unload,
            point: unload,
            arrival: time,
            departure: leave,
            loadAfterKg: 0,
          ),
        );
        time = leave;
        pos = unload;
        load = 0;
      }
      km += roadKm(pos, s.point);
      var arrival = time.add(_minutes(_travelMin(pos, s.point)));
      if (arrival.isAfter(s.windowEnd)) return null;
      var w = 0.0;
      if (arrival.isBefore(s.windowStart)) {
        w = s.windowStart.difference(arrival).inSeconds / 60;
        arrival = s.windowStart;
      }
      wait += w;
      load += s.kg;
      final leave = arrival.add(_minutes(config.serviceMinutes));
      visits.add(
        Visit(
          kind: VisitKind.pickup,
          stop: s,
          point: s.point,
          arrival: arrival,
          departure: leave,
          loadAfterKg: load,
          waitMinutes: w,
        ),
      );
      time = leave;
      pos = s.point;
    }
    return Tour(
      visits: visits,
      distanceKm: km,
      durationMinutes: time.difference(startAt).inSeconds / 60,
      waitMinutes: wait,
      unassigned: const [],
    );
  }

  double cost(Tour t) => config.distanceWeight * t.distanceKm + config.waitWeight * t.waitMinutes;

  /// Ordre optimisé ; les arrêts impossibles à placer sont renvoyés dans
  /// [Tour.unassigned] (jamais planifiés hors de leur créneau).
  Tour solve(
    List<Stop> stops, {
    required GeoPoint start,
    required DateTime startAt,
    required double capacityKg,
    GeoPoint? depot,
  }) {
    Tour? eval(List<Stop> o) =>
        evaluate(o, start: start, startAt: startAt, capacityKg: capacityKg, depot: depot);
    var order = <Stop>[];
    final unassigned = <Stop>[];
    // Construction : fenêtres les plus serrées d'abord, meilleure position.
    final pending = [...stops]..sort((a, b) => a.windowEnd.compareTo(b.windowEnd));
    for (final s in pending) {
      List<Stop>? best;
      double? bestCost;
      for (var i = 0; i <= order.length; i++) {
        final candidate = [...order]..insert(i, s);
        final t = eval(candidate);
        if (t == null) continue;
        final c = cost(t);
        if (bestCost == null || c < bestCost) {
          bestCost = c;
          best = candidate;
        }
      }
      if (best == null) {
        unassigned.add(s);
      } else {
        order = best;
      }
    }
    // Point de départ : le meilleur entre la construction et l'ordre naïf
    // (s'il sert tous les arrêts) — le résultat n'est jamais pire que lui.
    var current = eval(order);
    if (unassigned.isEmpty) {
      final naiveOrder = [...stops]..sort((a, b) => a.windowStart.compareTo(b.windowStart));
      final n = eval(naiveOrder);
      if (n != null && (current == null || cost(n) < cost(current))) {
        order = naiveOrder;
        current = n;
      }
    }
    // Recherche locale : 2-opt (inversion) et or-opt (déplacement d'un arrêt).
    var improved = current != null;
    while (improved) {
      improved = false;
      for (final candidate in _neighbours(order)) {
        final t = eval(candidate);
        if (t != null && cost(t) < cost(current!) - 1e-9) {
          order = candidate;
          current = t;
          improved = true;
          break;
        }
      }
    }
    final result =
        current ??
        const Tour(visits: [], distanceKm: 0, durationMinutes: 0, waitMinutes: 0, unassigned: []);
    return Tour(
      visits: result.visits,
      distanceKm: result.distanceKm,
      durationMinutes: result.durationMinutes,
      waitMinutes: result.waitMinutes,
      unassigned: unassigned,
    );
  }

  Iterable<List<Stop>> _neighbours(List<Stop> o) sync* {
    for (var i = 0; i < o.length - 1; i++) {
      for (var j = i + 1; j < o.length; j++) {
        yield [...o.sublist(0, i), ...o.sublist(i, j + 1).reversed, ...o.sublist(j + 1)];
      }
    }
    for (var i = 0; i < o.length; i++) {
      for (var j = 0; j < o.length; j++) {
        if (i == j) continue;
        final moved = [...o];
        final s = moved.removeAt(i);
        moved.insert(j, s);
        yield moved;
      }
    }
  }

  /// Ordre naïf de référence : par début de créneau, puis ordre reçu.
  Tour? naive(
    List<Stop> stops, {
    required GeoPoint start,
    required DateTime startAt,
    required double capacityKg,
    GeoPoint? depot,
  }) {
    final order = [...stops]..sort((a, b) => a.windowStart.compareTo(b.windowStart));
    return evaluate(order, start: start, startAt: startAt, capacityKg: capacityKg, depot: depot);
  }

  Savings savings(Tour optimized, Tour? reference, {required double litersPer100Km}) {
    final km = reference == null
        ? 0.0
        : (reference.distanceKm - optimized.distanceKm).clamp(0, double.infinity).toDouble();
    final minutes = reference == null
        ? 0.0
        : (reference.durationMinutes - optimized.durationMinutes)
              .clamp(0, double.infinity)
              .toDouble();
    final fuel = km * litersPer100Km / 100;
    return Savings(
      km: km,
      minutes: minutes,
      fuelL: fuel,
      co2Kg: fuel * config.co2KgPerLiter,
      dt: fuel * config.fuelPriceDt,
    );
  }
}

Duration _minutes(double m) => Duration(milliseconds: (m * 60000).round());

/// Vérifie qu'une tournée respecte créneaux et capacité (tests US-058).
bool tourRespectsConstraints(Tour t, double capacityKg) {
  for (final v in t.visits) {
    if (v.loadAfterKg > capacityKg + 1e-9) return false;
    final s = v.stop;
    if (s != null && (v.arrival.isAfter(s.windowEnd) || v.arrival.isBefore(s.windowStart))) {
      return false;
    }
  }
  return true;
}
