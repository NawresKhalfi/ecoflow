import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../collection/domain/collection_request.dart';
import '../../collection/domain/geo.dart';
import '../../missions/application/missions_providers.dart';
import '../../missions/domain/mission_rules.dart';
import '../../missions/domain/vehicle.dart';
import '../data/optimization_repository.dart';
import '../domain/clustering.dart';
import '../domain/detour.dart';
import '../domain/optimization_config.dart';
import '../domain/route_solver.dart';
import '../domain/tour.dart';

final optimizationRepositoryProvider = Provider(
  (ref) => OptimizationRepository(ref.watch(firestoreProvider)),
);

final optimizationConfigProvider = StreamProvider<OptimizationConfig>(
  (ref) => ref.watch(optimizationRepositoryProvider).watch(),
);

final optimizationHistoryProvider = StreamProvider(
  (ref) => ref.watch(optimizationRepositoryProvider).watchHistory(),
);

final routeSolverProvider = Provider<RouteSolver>(
  (ref) => RouteSolver(ref.watch(optimizationConfigProvider).value ?? const OptimizationConfig()),
);

Stop stopOf(CollectionRequest r) => Stop(
  id: r.id,
  point: r.place.point,
  kg: r.estimatedKg,
  windowStart: r.slot.start,
  windowEnd: r.slot.end,
  label: r.place.address,
);

const _activeStatuses = {
  CollectionStatus.accepted,
  CollectionStatus.onTheWay,
  CollectionStatus.arrived,
  CollectionStatus.inProgress,
};

/// Tournée planifiée du collecteur : missions acceptées non terminées du
/// premier jour qui en compte, recalculée à chaque ajout, annulation ou
/// retard (US-057 à US-059).
class TourPlan {
  const TourPlan({
    required this.day,
    required this.tour,
    required this.naive,
    required this.savings,
    required this.start,
    required this.startAt,
    required this.capacityKg,
    required this.missions,
    required this.computeMs,
  });

  final DateTime day;
  final Tour tour;
  final Tour? naive;
  final Savings savings;
  final GeoPoint start;
  final DateTime startAt;
  final double capacityKg;
  final Map<String, CollectionRequest> missions;
  final int computeMs;
}

double capacityOf(Vehicle? v) => v?.capacityKg ?? 200;

double litersOf(Vehicle? v) => fuelLitersPer100Km(v?.type ?? VehicleType.car);

final tourPlanProvider = Provider<TourPlan?>((ref) {
  final mine = ref.watch(myMissionsProvider).value ?? const [];
  final active = mine.where((m) => _activeStatuses.contains(m.status)).toList();
  if (active.isEmpty) return null;
  active.sort((a, b) => a.slot.start.compareTo(b.slot.start));
  final day = active.first.slot.date;
  final today = [
    for (final m in active)
      if (m.slot.date == day) m,
  ];
  final now = ref.watch(clockProvider)();
  final dayStart = DateTime(day.year, day.month, day.day, 8);
  final startAt = now.isAfter(dayStart) ? now : dayStart;
  final start = ref.watch(myPresenceDataProvider).value?.point ?? today.first.place.point;
  final vehicle = ref.watch(vehicleProvider).value;
  final solver = ref.watch(routeSolverProvider);
  final stops = today.map(stopOf).toList();
  final w = Stopwatch()..start();
  var departAt = startAt;
  var tour = solver.solve(stops, start: start, startAt: departAt, capacityKg: capacityOf(vehicle));
  // Départ le plus tard possible : pas d'attente devant le premier arrêt.
  final firstWait = tour.visits.isEmpty ? 0.0 : tour.visits.first.waitMinutes;
  if (firstWait >= 1) {
    final later = departAt.add(Duration(seconds: (firstWait * 60).floor()));
    final shifted = solver.evaluate(
      tour.order,
      start: start,
      startAt: later,
      capacityKg: capacityOf(vehicle),
    );
    if (shifted != null) {
      departAt = later;
      tour = Tour(
        visits: shifted.visits,
        distanceKm: shifted.distanceKm,
        durationMinutes: shifted.durationMinutes,
        waitMinutes: shifted.waitMinutes,
        unassigned: tour.unassigned,
      );
    }
  }
  final naive = solver.naive(
    stops,
    start: start,
    startAt: departAt,
    capacityKg: capacityOf(vehicle),
  );
  w.stop();
  return TourPlan(
    day: day,
    tour: tour,
    naive: naive,
    savings: solver.savings(tour, naive, litersPer100Km: litersOf(vehicle)),
    start: start,
    startAt: departAt,
    capacityKg: capacityOf(vehicle),
    missions: {for (final m in today) m.id: m},
    computeMs: w.elapsedMilliseconds,
  );
});

/// Missions ouvertes compatibles avec la tournée en cours (US-061).
final detourSuggestionsProvider = Provider<List<(CollectionRequest, DetourSuggestion)>>((ref) {
  final plan = ref.watch(tourPlanProvider);
  if (plan == null) return const [];
  final uid = ref.watch(currentUidProvider) ?? '';
  final now = ref.watch(clockProvider)();
  final open = [
    for (final m in ref.watch(openMissionsProvider).value ?? const <CollectionRequest>[])
      if (m.slot.date == plan.day && canAccept(m, uid, now)) m,
  ];
  final byId = {for (final m in open) m.id: m};
  final config = ref.watch(optimizationConfigProvider).value ?? const OptimizationConfig();
  final solver = ref.watch(routeSolverProvider);
  return [
    for (final s in detourSuggestions(
      solver,
      plan.tour.order,
      open.map(stopOf).toList(),
      start: plan.start,
      startAt: plan.startAt,
      capacityKg: plan.capacityKg,
      maxDetourKm: config.maxDetourKm,
    ))
      (byId[s.stop.id]!, s),
  ];
});

/// Regroupements de missions ouvertes proches (US-056) : groupes d'au
/// moins 2 collectes du même jour, dans la capacité du véhicule.
final missionClustersProvider = Provider<List<(List<CollectionRequest>, StopCluster)>>((ref) {
  final available = [for (final (m, _) in ref.watch(availableMissionsProvider)) m];
  if (available.length < 2) return const [];
  final config = ref.watch(optimizationConfigProvider).value ?? const OptimizationConfig();
  final capacity = capacityOf(ref.watch(vehicleProvider).value);
  final byDay = <DateTime, List<CollectionRequest>>{};
  for (final m in available) {
    byDay.putIfAbsent(m.slot.date, () => []).add(m);
  }
  final result = <(List<CollectionRequest>, StopCluster)>[];
  for (final day in byDay.values) {
    final byId = {for (final m in day) m.id: m};
    for (final c in clusterStops(
      day.map(stopOf).toList(),
      radiusKm: config.clusterRadiusKm,
      capacityKg: capacity,
    )) {
      if (c.stops.length >= 2) result.add(([for (final s in c.stops) byId[s.id]!], c));
    }
  }
  return result;
});

/// Publication des paramètres (US-062).
class OptimizationAdminController extends ActionController {
  Future<bool> publish(OptimizationConfig c) => run(
    () => ref
        .read(optimizationRepositoryProvider)
        .publish(c, ref.read(authRepositoryProvider).currentUser!.uid),
  );
}

final optimizationAdminControllerProvider =
    NotifierProvider.autoDispose<OptimizationAdminController, AsyncValue<void>>(
      OptimizationAdminController.new,
    );

/// Bilan de la dernière journée terminée (US-060) : économies de l'ordre
/// optimisé sur les collectes réellement réalisées ce jour-là.
final lastTourSavingsProvider = Provider<(DateTime, int, Savings)?>((ref) {
  final done = [
    for (final m in ref.watch(myMissionsProvider).value ?? const <CollectionRequest>[])
      if (m.status == CollectionStatus.completed || m.status == CollectionStatus.handedOver) m,
  ];
  if (done.length < 2) return null;
  done.sort((a, b) => b.slot.start.compareTo(a.slot.start));
  final day = done.first.slot.date;
  final ofDay = [
    for (final m in done)
      if (m.slot.date == day) m,
  ];
  if (ofDay.length < 2) return null;
  final solver = ref.watch(routeSolverProvider);
  final vehicle = ref.watch(vehicleProvider).value;
  final stops = ofDay.map(stopOf).toList();
  final start = ofDay.last.place.point;
  final at = DateTime(day.year, day.month, day.day, 8);
  final tour = solver.solve(stops, start: start, startAt: at, capacityKg: 1e6);
  final naive = solver.naive(stops, start: start, startAt: at, capacityKg: 1e6);
  return (day, ofDay.length, solver.savings(tour, naive, litersPer100Km: litersOf(vehicle)));
});
