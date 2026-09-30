enum DepositStatus { pending, confirmed, rejected }

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
