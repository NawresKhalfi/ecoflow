import '../../collection/domain/collection_request.dart';
import '../../collection/domain/geo.dart';
import 'work_zone.dart';

/// Délai de réponse à une proposition (US-044).
const proposalTimeout = Duration(seconds: 60);

bool proposalExpired(CollectionRequest r, DateTime now) =>
    r.status == CollectionStatus.proposed &&
    r.proposedAt != null &&
    !now.isBefore(r.proposedAt!.add(proposalTimeout));

Duration proposalRemaining(CollectionRequest r, DateTime now) {
  if (r.proposedAt == null) return Duration.zero;
  final left = r.proposedAt!.add(proposalTimeout).difference(now);
  return left.isNegative ? Duration.zero : left;
}

/// Mission que ce collecteur peut accepter : ouverte, ou proposée à lui
/// (non expirée), et pas refusée par lui.
bool canAccept(CollectionRequest r, String uid, DateTime now) {
  if (r.refusedBy.contains(uid) || r.citizenUid == uid) return false;
  return switch (r.status) {
    CollectionStatus.searching || CollectionStatus.noCollector => true,
    CollectionStatus.proposed => r.proposedCollectorUid == uid && !proposalExpired(r, now),
    _ => false,
  };
}

/// Étape suivante du déroulé sur place (US-047).
CollectionStatus? nextStep(CollectionStatus s) => switch (s) {
  CollectionStatus.accepted => CollectionStatus.onTheWay,
  CollectionStatus.onTheWay => CollectionStatus.arrived,
  CollectionStatus.arrived => CollectionStatus.inProgress,
  _ => null,
};

/// Clôture possible une fois sur place et la photo preuve prise (US-048/050).
bool canClose(CollectionRequest r, {required bool hasProof}) =>
    r.status == CollectionStatus.inProgress && hasProof;

/// Signalement citoyen absent / adresse introuvable : seulement une fois
/// arrivé (preuve de présence), sans pénalité pour le collecteur (US-053).
bool canReportNoShow(CollectionRequest r) =>
    r.status == CollectionStatus.arrived || r.status == CollectionStatus.inProgress;

enum MissionSort { distance, value }

/// Filtres de la liste des missions (US-043).
class MissionFilter {
  const MissionFilter({
    this.sort = MissionSort.distance,
    this.categories = const {},
    this.minKg = 0,
    this.maxKg,
  });

  final MissionSort sort;

  /// Vide = toutes les matières.
  final Set<String> categories;
  final double minKg;
  final double? maxKg;

  MissionFilter copyWith({
    MissionSort? sort,
    Set<String>? categories,
    double? minKg,
    double? maxKg,
    bool clearMax = false,
  }) => MissionFilter(
    sort: sort ?? this.sort,
    categories: categories ?? this.categories,
    minKg: minKg ?? this.minKg,
    maxKg: clearMax ? null : (maxKg ?? this.maxKg),
  );
}

/// Missions visibles : dans la zone de travail, selon filtres, triées.
List<(CollectionRequest, double?)> selectMissions(
  List<CollectionRequest> requests, {
  required MissionFilter filter,
  GeoPoint? from,
  WorkZone? zone,
}) {
  final result = <(CollectionRequest, double?)>[];
  for (final r in requests) {
    if (zone != null && !zone.contains(r.place.point)) continue;
    if (filter.categories.isNotEmpty && !r.categories.any(filter.categories.contains)) continue;
    if (r.estimatedKg < filter.minKg) continue;
    if (filter.maxKg != null && r.estimatedKg > filter.maxKg!) continue;
    result.add((r, from == null ? null : distanceKm(from, r.place.point)));
  }
  result.sort(
    (a, b) => filter.sort == MissionSort.value
        ? b.$1.estimatedDt.compareTo(a.$1.estimatedDt)
        : (a.$2 ?? 0).compareTo(b.$2 ?? 0),
  );
  return result;
}
