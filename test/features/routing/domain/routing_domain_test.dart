import 'dart:math';

import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/routing/domain/clustering.dart';
import 'package:ecoflow/features/routing/domain/detour.dart';
import 'package:ecoflow/features/routing/domain/optimization_config.dart';
import 'package:ecoflow/features/routing/domain/route_solver.dart';
import 'package:ecoflow/features/routing/domain/tour.dart';
import 'package:ecoflow/features/routing/domain/tour_change.dart';
import 'package:flutter_test/flutter_test.dart';

const depot = GeoPoint(35.8256, 10.6084);
final t8 = DateTime(2026, 10, 1, 8);

Stop stop(String id, double dLat, double dLng, {double kg = 5, int from = 8, int to = 18}) => Stop(
  id: id,
  point: GeoPoint(depot.lat + dLat, depot.lng + dLng),
  kg: kg,
  windowStart: DateTime(2026, 10, 1, from),
  windowEnd: DateTime(2026, 10, 1, to),
);

List<Stop> randomStops(Random r, int n) => [
  for (var i = 0; i < n; i++)
    () {
      final from = [8, 10, 14, 16][r.nextInt(4)];
      return stop(
        's$i',
        (r.nextDouble() - .5) * .12,
        (r.nextDouble() - .5) * .12,
        kg: 1 + r.nextDouble() * 30,
        from: from,
        to: from + 2,
      );
    }(),
];

void main() {
  const solver = RouteSolver(OptimizationConfig());

  test('beats a zig-zag naive order on a simple line (US-057)', () {
    // Ordre naïf (même créneau) : aller-retour ; optimal : de proche en proche.
    final stops = [stop('far', .04, 0), stop('near', .01, 0), stop('mid', .025, 0)];
    final best = solver.solve(stops, start: depot, startAt: t8, capacityKg: 500);
    expect(best.order.map((s) => s.id), ['near', 'mid', 'far']);
    final naive = solver.evaluate(stops, start: depot, startAt: t8, capacityKg: 500)!;
    expect(best.distanceKm, lessThan(naive.distanceKm));
    final s = solver.savings(best, naive, litersPer100Km: 10);
    expect(s.km, closeTo(naive.distanceKm - best.distanceKm, 1e-9));
    expect(s.co2Kg, closeTo(s.fuelL * 2.31, 1e-9));
    expect(s.isPositive, isTrue);
  });

  test('time windows are hard constraints; impossible stops are left out (US-058)', () {
    final late = stop('late', .01, 0, from: 14, to: 16);
    final early = stop('early', .03, 0, from: 8, to: 10);
    final best = solver.solve([late, early], start: depot, startAt: t8, capacityKg: 500);
    expect(best.order.map((s) => s.id), ['early', 'late'], reason: 'window order beats distance');
    expect(best.visits.last.arrival, DateTime(2026, 10, 1, 14), reason: 'waits for the window');
    final gone = solver.solve(
      [stop('past', .01, 0, from: 6, to: 7)],
      start: depot,
      startAt: t8,
      capacityKg: 500,
    );
    expect(gone.unassigned.single.id, 'past');
    expect(gone.visits, isEmpty);
  });

  test('capacity triggers unload trips; oversized stops are refused (US-058)', () {
    final stops = [for (var i = 0; i < 4; i++) stop('s$i', .005 * (i + 1), 0, kg: 40)];
    final t = solver.solve(stops, start: depot, startAt: t8, capacityKg: 100);
    expect(t.visits.where((v) => v.kind == VisitKind.unload), hasLength(1));
    expect(tourRespectsConstraints(t, 100), isTrue);
    expect(
      solver
          .solve([stop('huge', .01, 0, kg: 300)], start: depot, startAt: t8, capacityKg: 100)
          .unassigned,
      hasLength(1),
    );
  });

  test('100 % of generated tours respect windows and capacity (US-058)', () {
    final r = Random(42);
    for (var run = 0; run < 200; run++) {
      final cap = 40 + r.nextDouble() * 160;
      final t = solver.solve(
        randomStops(r, 3 + r.nextInt(10)),
        start: depot,
        startAt: t8,
        capacityKg: cap,
      );
      expect(tourRespectsConstraints(t, cap), isTrue, reason: 'run $run');
    }
  });

  test('never worse than the naive order when the naive order is feasible', () {
    final r = Random(7);
    var compared = 0;
    for (var run = 0; run < 100; run++) {
      final stops = randomStops(r, 8);
      final naive = solver.naive(stops, start: depot, startAt: t8, capacityKg: 1000);
      final best = solver.solve(stops, start: depot, startAt: t8, capacityKg: 1000);
      if (naive == null || best.unassigned.isNotEmpty) continue;
      compared++;
      expect(solver.cost(best), lessThanOrEqualTo(solver.cost(naive) + 1e-6), reason: 'run $run');
    }
    expect(compared, greaterThan(50));
  });

  test('30 stops are solved well under 10 s (US-059)', () {
    final stops = [for (var i = 0; i < 30; i++) stop('s$i', (i % 6) * .01, (i ~/ 6) * .01, kg: 3)];
    final w = Stopwatch()..start();
    final t = solver.solve(stops, start: depot, startAt: t8, capacityKg: 500);
    w.stop();
    expect(t.order, hasLength(30));
    expect(w.elapsed, lessThan(const Duration(seconds: 10)));
  });

  test('clusters nearby stops within capacity (US-056)', () {
    final stops = [stop('a', 0, 0), stop('b', .005, 0), stop('c', .006, .003), stop('far', .3, .3)];
    final c = clusterStops(stops, radiusKm: 2, capacityKg: 100);
    expect(c.first.stops.map((s) => s.id).toSet(), {'a', 'b', 'c'});
    expect(c.last.stops.single.id, 'far');
    final tight = clusterStops(stops.take(3).toList(), radiusKm: 2, capacityKg: 10);
    expect(tight.every((g) => g.totalKg <= 10), isTrue);
  });

  test('detour suggestions stay within the max detour (US-061)', () {
    final current = [stop('a', .01, 0), stop('b', .03, 0)];
    final onTheWay = stop('onway', .02, .001);
    final far = stop('far', .02, .08);
    final s = detourSuggestions(
      solver,
      current,
      [onTheWay, far],
      start: depot,
      startAt: t8,
      capacityKg: 500,
      maxDetourKm: 2,
    );
    expect(s.map((x) => x.stop.id), ['onway']);
    expect(s.single.position, 1);
    expect(s.single.extraKm, lessThan(2));
  });

  test('tour change detection (US-059)', () {
    expect(diffOrder(['a', 'b'], ['a', 'b']), TourChange.none);
    expect(diffOrder(['a', 'b'], ['b', 'a']), TourChange.reordered);
    expect(diffOrder(['a'], ['a', 'c']), TourChange.added);
    expect(diffOrder(['a', 'b'], ['a']), TourChange.removed);
  });

  test('config round-trip and fuel table (US-062)', () {
    final c = OptimizationConfig.fromMap(
      const OptimizationConfig(maxDetourKm: 5, waitWeight: .5).toMap(),
    );
    expect(c.maxDetourKm, 5);
    expect(c.waitWeight, .5);
    expect(OptimizationConfig.fromMap(null).roadFactor, 1.3);
  });
}
