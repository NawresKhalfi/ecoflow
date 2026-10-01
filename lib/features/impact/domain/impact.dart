import '../../estimation/domain/estimate_record.dart';
import '../../market/domain/market.dart';
import '../../recycler/domain/reception.dart';
import '../../scan/domain/waste_category.dart';
import '../../wallet/domain/wallet.dart';

/// Émissions évitées par kg pour une catégorie du catalogue (US-119) :
/// facteur de sa matière, déchets médicaux exclus (non recyclés), déchets
/// organiques compostés comptés à un ordre de grandeur bas.
double co2PerKgForCategory(String categoryId, List<WasteCategory> catalog) => switch (categoryId) {
  'medical' => 0,
  'organic' => .1,
  _ => co2AvoidedPerKg(materialForCategory(categoryId, catalog)),
};

/// Équivalences parlantes du CO₂ évité (ordres de grandeur ADEME / EPA).
abstract final class Co2Equivalent {
  /// Voiture thermique moyenne : ~0,19 kg CO₂e par km.
  static const kgPerCarKm = .193;

  /// Un arbre adulte absorbe ~25 kg de CO₂ par an.
  static const kgPerTreeYear = 25.0;

  /// Recharge complète d'un smartphone : ~8,2 g CO₂e.
  static const kgPerPhoneCharge = .0082;
}

/// Contribution d'un mois (US-118).
class MonthStat {
  const MonthStat({
    required this.month,
    this.kg = 0,
    this.collections = 0,
    this.valueDt = 0,
    this.co2Kg = 0,
    this.points = 0,
  });

  /// Premier jour du mois.
  final DateTime month;
  final double kg;
  final int collections;
  final double valueDt;
  final double co2Kg;
  final int points;

  MonthStat add({double kg = 0, int collections = 0, double dt = 0, double co2 = 0, int pts = 0}) =>
      MonthStat(
        month: month,
        kg: this.kg + kg,
        collections: this.collections + collections,
        valueDt: valueDt + dt,
        co2Kg: co2Kg + co2,
        points: points + pts,
      );
}

/// Tableau de bord personnel du citoyen (US-118, US-119).
class PersonalImpact {
  const PersonalImpact({
    required this.months,
    required this.totalKg,
    required this.collections,
    required this.valueDt,
    required this.co2Kg,
    required this.points,
    required this.kgByCategory,
    required this.co2ByCategory,
  });

  /// Du plus ancien au mois en cours.
  final List<MonthStat> months;
  final double totalKg;
  final int collections;
  final double valueDt;
  final double co2Kg;

  /// Points gagnés au total (gains crédités).
  final int points;
  final Map<String, double> kgByCategory;
  final Map<String, double> co2ByCategory;

  MonthStat get current => months.last;
  MonthStat get previous => months[months.length - 2];

  /// Évolution des kilos par rapport au mois précédent ; `null` sans base.
  double? get kgTrend => previous.kg == 0 ? null : (current.kg - previous.kg) / previous.kg;

  double get carKm => co2Kg / Co2Equivalent.kgPerCarKm;
  double get treeYears => co2Kg / Co2Equivalent.kgPerTreeYear;
  double get phoneCharges => co2Kg / Co2Equivalent.kgPerPhoneCharge;
  bool get isEmpty => collections == 0;
}

DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

/// Agrège les pesées validées et les gains de points sur [monthCount] mois
/// glissants (mois en cours inclus) ; les totaux couvrent tout l'historique.
PersonalImpact personalImpact({
  required List<EstimateRecord> estimates,
  required List<LedgerEntry> entries,
  required List<WasteCategory> catalog,
  required DateTime now,
  int monthCount = 6,
}) {
  assert(monthCount >= 2);
  final first = DateTime(now.year, now.month - monthCount + 1);
  final months = [
    for (var i = 0; i < monthCount; i++) MonthStat(month: DateTime(first.year, first.month + i)),
  ];
  int? slot(DateTime? d) {
    if (d == null) return null;
    final m = monthOf(d);
    final i = (m.year - first.year) * 12 + m.month - first.month;
    return i >= 0 && i < monthCount ? i : null;
  }

  var totalKg = 0.0, valueDt = 0.0, co2 = 0.0, collections = 0;
  final kgBy = <String, double>{};
  final co2By = <String, double>{};
  for (final e in estimates.where((e) => e.isWeighed)) {
    final w = e.weighing!;
    var c = 0.0;
    for (final MapEntry(key: id, value: kg) in e.actualKg.entries) {
      final x = kg * co2PerKgForCategory(id, catalog);
      c += x;
      kgBy[id] = (kgBy[id] ?? 0) + kg;
      co2By[id] = (co2By[id] ?? 0) + x;
    }
    totalKg += w.actualKg;
    valueDt += w.finalDt;
    co2 += c;
    collections++;
    final i = slot(e.weighedAt ?? e.createdAt);
    if (i != null) months[i] = months[i].add(kg: w.actualKg, collections: 1, dt: w.finalDt, co2: c);
  }
  var points = 0;
  for (final e in entries.where((e) => e.isCredit)) {
    points += e.points;
    final i = slot(e.at);
    if (i != null) months[i] = months[i].add(pts: e.points);
  }
  return PersonalImpact(
    months: months,
    totalKg: totalKg,
    collections: collections,
    valueDt: valueDt,
    co2Kg: co2,
    points: points,
    kgByCategory: kgBy,
    co2ByCategory: co2By,
  );
}
