import '../../auth/domain/user_role.dart';
import '../../collection/domain/geo.dart';
import '../../market/domain/market.dart';
import '../../profile/domain/company_profile.dart';

/// Collecte ramenée à ce dont les indicateurs ont besoin.
class CollectionStat {
  const CollectionStat({
    required this.id,
    required this.status,
    required this.zoneId,
    required this.createdAt,
    this.citizenUid,
    this.collectorUid,
    this.point,
    this.acceptedAt,
    this.completedAt,
    this.estimatedKg = 0,
    this.actualKg = const {},
    this.cancelledBy,
  });

  final String id;
  final String status;
  final String zoneId;
  final DateTime createdAt;
  final String? citizenUid;
  final String? collectorUid;
  final GeoPoint? point;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final double estimatedKg;

  /// Pesée réelle par matière.
  final Map<RecyclableMaterial, double> actualKg;
  final String? cancelledBy;

  double get actualTotal => actualKg.values.fold(0, (a, b) => a + b);
  bool get weighed => actualKg.isNotEmpty;
}

/// Statuts « en cours » (carte de supervision, US-108).
const liveStatuses = [
  'searching',
  'noCollector',
  'proposed',
  'accepted',
  'onTheWay',
  'arrived',
  'inProgress',
  'handedOver',
];

/// Indicateurs de la plateforme sur une période (US-109 à US-111).
class PlatformStats {
  const PlatformStats({
    required this.kgByMaterial,
    required this.requests,
    required this.completed,
    required this.cancelled,
    required this.matched,
    required this.activeUsers,
    required this.newUsers,
    required this.co2Kg,
    this.avgAcceptMinutes,
    this.avgCompletionHours,
    this.aiAccuracy,
  });

  final Map<RecyclableMaterial, double> kgByMaterial;
  final int requests;
  final int completed;
  final int cancelled;

  /// Demandes ayant trouvé un collecteur.
  final int matched;

  /// Utilisateurs ayant eu une activité (demande ou mission) sur la période.
  final Map<UserRole, int> activeUsers;
  final Map<UserRole, int> newUsers;

  /// CO₂ évité estimé (kg CO₂e).
  final double co2Kg;

  /// Délai moyen entre la demande et l'acceptation par un collecteur.
  final double? avgAcceptMinutes;

  /// Délai moyen entre la demande et la fin de la collecte.
  final double? avgCompletionHours;

  /// Précision de l'estimation IA : 1 − écart relatif moyen estimé / pesé.
  final double? aiAccuracy;

  double get totalKg => kgByMaterial.values.fold(0, (a, b) => a + b);
  double get tonnes => totalKg / 1000;
  double get matchingRate => requests == 0 ? 0 : matched / requests;
  double get cancelRate => requests == 0 ? 0 : cancelled / requests;
  int get activeTotal => activeUsers.values.fold(0, (a, b) => a + b);
}

typedef UserStat = ({String uid, UserRole role, DateTime? createdAt});

PlatformStats platformStats(
  List<CollectionStat> all,
  List<UserStat> users,
  DateTime from,
  DateTime to,
) {
  bool inPeriod(DateTime d) => !d.isBefore(from) && !d.isAfter(to);
  final period = all.where((c) => inPeriod(c.createdAt)).toList();
  final done = all.where((c) => c.status == 'completed' && inPeriod(c.completedAt ?? c.createdAt));
  final kg = <RecyclableMaterial, double>{};
  var co2 = 0.0;
  for (final c in done) {
    for (final e in c.actualKg.entries) {
      kg[e.key] = (kg[e.key] ?? 0) + e.value;
      co2 += e.value * co2AvoidedPerKg(e.key);
    }
  }
  final accepted = [
    for (final c in period)
      if (c.acceptedAt != null) c.acceptedAt!.difference(c.createdAt).inSeconds / 60,
  ];
  final completion = [
    for (final c in done)
      if (c.completedAt != null) c.completedAt!.difference(c.createdAt).inMinutes / 60,
  ];
  final errors = [
    for (final c in done)
      if (c.weighed && c.actualTotal > 0) (c.estimatedKg - c.actualTotal).abs() / c.actualTotal,
  ];
  final roleOf = {for (final u in users) u.uid: u.role};
  final active = <String>{
    for (final c in period) ...[?c.citizenUid, ?c.collectorUid],
  };
  final activeByRole = <UserRole, int>{};
  for (final uid in active) {
    final r = roleOf[uid];
    if (r != null) activeByRole[r] = (activeByRole[r] ?? 0) + 1;
  }
  final newByRole = <UserRole, int>{};
  for (final u in users.where((u) => u.createdAt != null && inPeriod(u.createdAt!))) {
    newByRole[u.role] = (newByRole[u.role] ?? 0) + 1;
  }
  double? mean(List<double> v) => v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
  final err = mean(errors);
  return PlatformStats(
    kgByMaterial: kg,
    requests: period.length,
    completed: done.length,
    cancelled: period.where((c) => c.status == 'cancelled').length,
    matched: period.where((c) => c.collectorUid != null).length,
    activeUsers: activeByRole,
    newUsers: newByRole,
    co2Kg: co2,
    avgAcceptMinutes: mean(accepted),
    avgCompletionHours: mean(completion),
    aiAccuracy: err == null ? null : (1 - err).clamp(0, 1).toDouble(),
  );
}

/// Objectif de réponse d'un scan (US-124) : inférence sur l'appareil.
const scanTargetMs = 5000;

typedef ScanTiming = ({DateTime? at, int ms});

/// 90ᵉ centile du temps d'analyse et part des scans sous l'objectif.
({int? p90Ms, double? withinTarget, int count}) scanLatency(
  List<ScanTiming> scans,
  DateTime from,
  DateTime to,
) {
  final ms = [
    for (final s in scans)
      if (s.at == null || (!s.at!.isBefore(from) && !s.at!.isAfter(to))) s.ms,
  ]..sort();
  if (ms.isEmpty) return (p90Ms: null, withinTarget: null, count: 0);
  final rank = (ms.length * .9).ceil() - 1;
  return (
    p90Ms: ms[rank.clamp(0, ms.length - 1)],
    withinTarget: ms.where((m) => m < scanTargetMs).length / ms.length,
    count: ms.length,
  );
}
