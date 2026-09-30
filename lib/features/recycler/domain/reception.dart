import '../../profile/domain/company_profile.dart';
import '../../scan/domain/waste_category.dart';
import 'stock.dart';

/// Matière du recycleur pour une catégorie du catalogue (canettes →
/// aluminium, papier → carton…). Les plastiques non identifiés vont en
/// « autres » : le recycleur les reclasse en PET / PEHD / PP à la réception.
RecyclableMaterial materialForCategory(String categoryId, List<WasteCategory> catalog) =>
    catalog.where((c) => c.id == categoryId).firstOrNull?.material ?? RecyclableMaterial.other;

/// Poids déclarés par le collecteur, regroupés par matière (pré-remplissage).
Map<RecyclableMaterial, double> declaredByMaterial(
  Map<String, double> byCategoryKg,
  List<WasteCategory> catalog,
) {
  final out = <RecyclableMaterial, double>{};
  for (final e in byCategoryKg.entries) {
    final m = materialForCategory(e.key, catalog);
    out[m] = (out[m] ?? 0) + e.value;
  }
  return out;
}

/// Contrôle à la réception d'un dépôt (US-080).
class ReceptionInput {
  const ReceptionInput({
    required this.kgByMaterial,
    required this.grade,
    this.contaminationPct = 0,
    this.note = '',
  });

  /// Poids pesés à l'entrée, par matière (0 = absente).
  final Map<RecyclableMaterial, double> kgByMaterial;
  final QualityGrade grade;

  /// Part d'indésirables estimée (0–100 %).
  final double contaminationPct;
  final String note;

  double get totalKg => kgByMaterial.values.fold(0, (a, b) => a + b);
}

enum ReceptionIssue { empty, negative, contamination }

ReceptionIssue? validateReception(ReceptionInput r) {
  if (r.kgByMaterial.values.any((v) => v < 0)) return ReceptionIssue.negative;
  if (r.totalKg <= 0) return ReceptionIssue.empty;
  if (r.contaminationPct < 0 || r.contaminationPct > 100) return ReceptionIssue.contamination;
  return null;
}

/// Écart relatif entre poids pesé et poids déclaré par le collecteur ;
/// signalé au-delà de 15 %.
double receptionGap(double declaredKg, double receivedKg) =>
    declaredKg <= 0 ? 0 : (receivedKg - declaredKg) / declaredKg;

const receptionGapWarning = .15;
