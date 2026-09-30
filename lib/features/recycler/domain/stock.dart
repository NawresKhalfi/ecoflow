import '../../missions/domain/deposit.dart';
import '../../profile/domain/company_profile.dart';

/// Qualité d'un lot à la réception (US-080) : A = propre et trié,
/// B = légèrement souillé, C = à retrier.
enum QualityGrade {
  a,
  b,
  c;

  /// Valeur utilisée pour la qualité moyenne du dashboard.
  double get score => switch (this) {
    QualityGrade.a => 1,
    QualityGrade.b => .6,
    QualityGrade.c => .3,
  };
}

/// Forme de la matière : brute à la réception, transformée en production.
enum MaterialForm { raw, bales, flakes, granules }

enum LotSource { reception, production }

/// Lot en stock : `lots/{id}` (US-081).
class StockLot {
  const StockLot({
    required this.id,
    required this.recyclerUid,
    required this.material,
    required this.grade,
    required this.initialKg,
    required this.kg,
    this.form = MaterialForm.raw,
    this.source = LotSource.reception,
    this.depositId,
    this.collectorUid,
    this.collectorName,
    this.zoneIds = const [],
    this.missions = const [],
    this.inputLotIds = const [],
    this.marketplace = false,
    this.receivedAt,
  });

  final String id;
  final String recyclerUid;
  final RecyclableMaterial material;
  final QualityGrade grade;
  final MaterialForm form;
  final LotSource source;

  /// Poids à l'entrée en stock, puis restant.
  final double initialKg;
  final double kg;
  final String? depositId;
  final String? collectorUid;
  final String? collectorName;
  final List<String> zoneIds;
  final List<MissionRef> missions;

  /// Lots consommés par la production qui a créé ce lot.
  final List<String> inputLotIds;

  /// Proposé sur la marketplace (epic 11).
  final bool marketplace;
  final DateTime? receivedAt;

  bool get inStock => kg > 1e-9;

  /// Référence courte affichée et imprimée sur les étiquettes.
  String get reference => 'LOT-${(id.length > 6 ? id.substring(0, 6) : id).toUpperCase()}';

  Map<String, dynamic> toMap() => {
    'recyclerUid': recyclerUid,
    'material': material.name,
    'grade': grade.name,
    'form': form.name,
    'source': source.name,
    'initialKg': initialKg,
    'kg': kg,
    'depositId': depositId,
    'collectorUid': collectorUid,
    'collectorName': collectorName,
    'zoneIds': zoneIds,
    'missions': [for (final m in missions) m.toMap()],
    'inputLotIds': inputLotIds,
    'marketplace': marketplace,
  };

  static StockLot fromMap(String id, Map<String, dynamic> m, DateTime? Function(Object?) date) =>
      StockLot(
        id: id,
        recyclerUid: m['recyclerUid'] as String? ?? '',
        material: materialFromName(m['material'] as String?),
        grade: QualityGrade.values.where((g) => g.name == m['grade']).firstOrNull ?? QualityGrade.b,
        form: MaterialForm.values.where((f) => f.name == m['form']).firstOrNull ?? MaterialForm.raw,
        source:
            LotSource.values.where((s) => s.name == m['source']).firstOrNull ?? LotSource.reception,
        initialKg: (m['initialKg'] as num?)?.toDouble() ?? 0,
        kg: (m['kg'] as num?)?.toDouble() ?? 0,
        depositId: m['depositId'] as String?,
        collectorUid: m['collectorUid'] as String?,
        collectorName: m['collectorName'] as String?,
        zoneIds: (m['zoneIds'] as List? ?? const []).cast<String>(),
        missions: [
          for (final x in (m['missions'] as List? ?? const [])) MissionRef.fromMap(x as Map, date),
        ],
        inputLotIds: (m['inputLotIds'] as List? ?? const []).cast<String>(),
        marketplace: m['marketplace'] as bool? ?? false,
        receivedAt: date(m['receivedAt']),
      );
}

RecyclableMaterial materialFromName(String? n) =>
    RecyclableMaterial.values.where((v) => v.name == n).firstOrNull ?? RecyclableMaterial.other;

enum MoveReason { reception, production, sale, loss, adjust }

/// Mouvement de stock : `stockMoves/{id}`, immuable.
class StockMove {
  const StockMove({
    required this.id,
    required this.lotId,
    required this.material,
    required this.deltaKg,
    required this.reason,
    this.note = '',
    this.at,
  });

  final String id;
  final String lotId;
  final RecyclableMaterial material;
  final double deltaKg;
  final MoveReason reason;
  final String note;
  final DateTime? at;
}

/// Stock disponible par matière puis par qualité (US-081).
Map<RecyclableMaterial, Map<QualityGrade, double>> stockSummary(Iterable<StockLot> lots) {
  final out = <RecyclableMaterial, Map<QualityGrade, double>>{};
  for (final l in lots.where((l) => l.inStock)) {
    final byGrade = out.putIfAbsent(l.material, () => {});
    byGrade[l.grade] = (byGrade[l.grade] ?? 0) + l.kg;
  }
  return out;
}

double totalKg(Map<QualityGrade, double> byGrade) => byGrade.values.fold(0, (a, b) => a + b);

class InsufficientStock implements Exception {
  const InsufficientStock(this.availableKg);
  final double availableKg;
}

/// Prélèvement « premier entré, premier sorti » de [kg] dans les lots de
/// [material] (et de [grade] si précisé). Renvoie (lot, kg prélevé).
List<(StockLot, double)> consumeFifo(
  Iterable<StockLot> lots,
  RecyclableMaterial material,
  double kg, {
  QualityGrade? grade,
}) {
  final candidates =
      lots
          .where((l) => l.inStock && l.material == material && (grade == null || l.grade == grade))
          .toList()
        ..sort(
          (a, b) => (a.receivedAt ?? DateTime(2000)).compareTo(b.receivedAt ?? DateTime(2000)),
        );
  final available = candidates.fold(0.0, (s, l) => s + l.kg);
  if (kg <= 0 || kg > available + 1e-9) throw InsufficientStock(available);
  final out = <(StockLot, double)>[];
  var left = kg;
  for (final l in candidates) {
    if (left <= 1e-9) break;
    final take = left < l.kg ? left : l.kg;
    out.add((l, take));
    left -= take;
  }
  return out;
}
