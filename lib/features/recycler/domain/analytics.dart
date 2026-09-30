import '../../profile/domain/company_profile.dart';
import 'stock.dart';

/// Période d'analyse du dashboard (US-082).
enum ReportPeriod {
  week(7),
  month(30),
  quarter(90),
  year(365);

  const ReportPeriod(this.days);
  final int days;
}

/// Filtres du dashboard : période, zone, collecteur (US-082).
class DashboardFilter {
  const DashboardFilter({this.period = ReportPeriod.month, this.zoneId, this.collectorUid});

  final ReportPeriod period;
  final String? zoneId;
  final String? collectorUid;

  DashboardFilter copyWith({
    ReportPeriod? period,
    String? Function()? zoneId,
    String? Function()? collectorUid,
  }) => DashboardFilter(
    period: period ?? this.period,
    zoneId: zoneId == null ? this.zoneId : zoneId(),
    collectorUid: collectorUid == null ? this.collectorUid : collectorUid(),
  );

  bool matches(StockLot l, DateTime now) {
    if (l.source != LotSource.reception || l.receivedAt == null) return false;
    if (l.receivedAt!.isBefore(now.subtract(Duration(days: period.days)))) return false;
    if (zoneId != null && !l.zoneIds.contains(zoneId)) return false;
    if (collectorUid != null && l.collectorUid != collectorUid) return false;
    return true;
  }
}

/// Synthèse des approvisionnements (US-079).
class SupplyReport {
  const SupplyReport({
    required this.lots,
    required this.byMaterial,
    required this.byCollector,
    required this.weekly,
  });

  final List<StockLot> lots;
  final Map<RecyclableMaterial, double> byMaterial;

  /// uid → (nom, kg)
  final Map<String, ({String name, double kg})> byCollector;

  /// kg reçus par semaine, de la plus ancienne à la plus récente.
  final List<double> weekly;

  double get totalKg => byMaterial.values.fold(0, (a, b) => a + b);
  int get deposits => {for (final l in lots) l.depositId}.length;

  /// Qualité moyenne pondérée par le poids (0–1).
  double get quality {
    final kg = lots.fold(0.0, (s, l) => s + l.initialKg);
    if (kg == 0) return 0;
    return lots.fold(0.0, (s, l) => s + l.grade.score * l.initialKg) / kg;
  }

  /// Parts par matière (tri décroissant).
  List<MapEntry<RecyclableMaterial, double>> get ranked =>
      byMaterial.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

SupplyReport supplyReport(List<StockLot> all, DashboardFilter f, DateTime now) {
  final lots = all.where((l) => f.matches(l, now)).toList()
    ..sort((a, b) => b.receivedAt!.compareTo(a.receivedAt!));
  final byMaterial = <RecyclableMaterial, double>{};
  final byCollector = <String, ({String name, double kg})>{};
  final weeks = (f.period.days / 7).ceil().clamp(1, 13);
  final weekly = List<double>.filled(weeks, 0);
  for (final l in lots) {
    byMaterial[l.material] = (byMaterial[l.material] ?? 0) + l.initialKg;
    final c = l.collectorUid ?? '';
    final prev = byCollector[c];
    byCollector[c] = (
      name: l.collectorName ?? prev?.name ?? '—',
      kg: (prev?.kg ?? 0) + l.initialKg,
    );
    final age = now.difference(l.receivedAt!).inDays ~/ 7;
    if (age < weeks) weekly[weeks - 1 - age] += l.initialKg;
  }
  return SupplyReport(lots: lots, byMaterial: byMaterial, byCollector: byCollector, weekly: weekly);
}

/// Zones et collecteurs présents dans les réceptions (listes des filtres).
({Set<String> zones, Map<String, String> collectors}) filterChoices(List<StockLot> lots) => (
  zones: {for (final l in lots) ...l.zoneIds},
  collectors: {
    for (final l in lots)
      if (l.collectorUid != null) l.collectorUid!: l.collectorName ?? l.collectorUid!,
  },
);

/// Déclaration de production (US-087) : matière consommée → produit.
class ProductionInput {
  const ProductionInput({
    required this.material,
    required this.inputKg,
    required this.form,
    required this.outputKg,
    required this.grade,
    this.marketplace = true,
  });

  final RecyclableMaterial material;
  final double inputKg;
  final MaterialForm form;
  final double outputKg;
  final QualityGrade grade;
  final bool marketplace;

  /// Rendement matière (sortie / entrée).
  double get yieldRatio => inputKg == 0 ? 0 : outputKg / inputKg;
}

enum ProductionIssue { noInput, noOutput, overYield, rawForm }

ProductionIssue? validateProduction(ProductionInput p) {
  if (p.inputKg <= 0) return ProductionIssue.noInput;
  if (p.outputKg <= 0) return ProductionIssue.noOutput;
  if (p.outputKg > p.inputKg + 1e-9) return ProductionIssue.overYield;
  if (p.form == MaterialForm.raw) return ProductionIssue.rawForm;
  return null;
}
