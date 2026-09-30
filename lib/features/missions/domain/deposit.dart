enum DepositStatus { pending, confirmed, rejected }

/// Collecte d'origine d'un lot, instantané pris au dépôt (US-084). Pas
/// d'adresse du citoyen : zone, jour et poids suffisent à la traçabilité.
class MissionRef {
  const MissionRef({required this.id, required this.zoneId, required this.day, required this.kg});

  final String id;
  final String zoneId;
  final DateTime day;
  final double kg;

  Map<String, dynamic> toMap() => {'id': id, 'zoneId': zoneId, 'day': day, 'kg': kg};

  static MissionRef fromMap(Map m, DateTime? Function(Object?) date) => MissionRef(
    id: m['id'] as String? ?? '',
    zoneId: m['zoneId'] as String? ?? '',
    day: date(m['day']) ?? DateTime(2000),
    kg: (m['kg'] as num?)?.toDouble() ?? 0,
  );
}

/// Dépôt d'une tournée chez un recycleur : `deposits/{id}` (US-055).
class Deposit {
  const Deposit({
    required this.id,
    required this.collectorUid,
    required this.recyclerUid,
    required this.recyclerName,
    required this.missionIds,
    required this.byCategoryKg,
    this.status = DepositStatus.pending,
    this.createdAt,
    this.note = '',
    this.collectorName,
    this.zoneIds = const [],
    this.missions = const [],
    this.receivedKg = const {},
    this.quality,
    this.contaminationPct,
    this.lotIds = const [],
  });

  final String id;
  final String collectorUid;
  final String recyclerUid;
  final String recyclerName;
  final List<String> missionIds;
  final Map<String, double> byCategoryKg;
  final DepositStatus status;
  final DateTime? createdAt;
  final String note;

  /// Traçabilité (US-084), instantané pris par le collecteur au dépôt.
  final String? collectorName;
  final List<String> zoneIds;
  final List<MissionRef> missions;

  /// Réception par le recycleur (US-080) : poids pesés par matière,
  /// qualité (a / b / c), part d'indésirables, lots créés.
  final Map<String, double> receivedKg;
  final String? quality;
  final double? contaminationPct;
  final List<String> lotIds;

  double get receivedTotalKg => receivedKg.values.fold(0, (a, b) => a + b);

  double get totalKg => byCategoryKg.values.fold(0, (a, b) => a + b);
}

/// Additionne les poids réels par catégorie des missions déposées.
Map<String, double> aggregateByCategory(Iterable<Map<String, double>> perMission) {
  final total = <String, double>{};
  for (final m in perMission) {
    for (final e in m.entries) {
      total[e.key] = (total[e.key] ?? 0) + e.value;
    }
  }
  return total;
}
