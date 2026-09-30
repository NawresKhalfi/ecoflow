import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../data/report_export.dart';
import '../../domain/analytics.dart';
import '../../domain/purchasing.dart';
import '../../domain/stock.dart';

String gradeLabel(AppLocalizations l, QualityGrade g) => switch (g) {
  QualityGrade.a => l.gradeA,
  QualityGrade.b => l.gradeB,
  QualityGrade.c => l.gradeC,
};

String formLabel(AppLocalizations l, MaterialForm f) => switch (f) {
  MaterialForm.raw => l.formRaw,
  MaterialForm.bales => l.formBales,
  MaterialForm.flakes => l.formFlakes,
  MaterialForm.granules => l.formGranules,
};

String moveLabel(AppLocalizations l, MoveReason r) => switch (r) {
  MoveReason.reception => l.moveReception,
  MoveReason.production => l.moveProduction,
  MoveReason.sale => l.moveSale,
  MoveReason.loss => l.moveLoss,
  MoveReason.adjust => l.moveAdjust,
};

String periodLabel(AppLocalizations l, ReportPeriod p) => switch (p) {
  ReportPeriod.week => l.period7,
  ReportPeriod.month => l.period30,
  ReportPeriod.quarter => l.period90,
  ReportPeriod.year => l.period365,
};

String materialEmoji(RecyclableMaterial m) => switch (m) {
  RecyclableMaterial.pet => '🧴',
  RecyclableMaterial.hdpe => '🧪',
  RecyclableMaterial.pp => '🥡',
  RecyclableMaterial.cardboard => '📦',
  RecyclableMaterial.aluminium => '🥫',
  RecyclableMaterial.glass => '🍾',
  RecyclableMaterial.other => '♻️',
};

/// Couleur fixe par matière (jamais selon le rang), en ordre catégoriel.
Color materialColor(RecyclableMaterial m) => switch (m) {
  RecyclableMaterial.pet => EcoColors.skyDeep,
  RecyclableMaterial.hdpe => EcoColors.violet,
  RecyclableMaterial.pp => EcoColors.sunDeep,
  RecyclableMaterial.cardboard => const Color(0xFFB5763A),
  RecyclableMaterial.aluminium => const Color(0xFF6B7C85),
  RecyclableMaterial.glass => EcoColors.primary,
  RecyclableMaterial.other => const Color(0xFFD9546B),
};

/// Zone affichée : identifiant technique mis en forme (« sousse » → « Sousse »).
String zoneLabel(String id) => id.isEmpty
    ? '—'
    : id
          .split(RegExp('[-_]'))
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');

/// Textes du rapport exporté. L'arabe n'est pas couvert par la police
/// embarquée : le rapport est alors produit en français.
ReportLabels reportLabels(
  BuildContext context, {
  required String company,
  required DashboardFilter f,
}) {
  final lang = Localizations.localeOf(context).languageCode;
  final l = lang == 'ar' ? lookupAppLocalizations(const Locale('fr')) : context.l10n;
  final locale = lang == 'ar' ? 'fr' : lang;
  return ReportLabels(
    title: l.reportTitle,
    company: company,
    period: periodLabel(l, f.period),
    filters: [
      if (f.zoneId != null) '${l.dashZone} : ${zoneLabel(f.zoneId!)}',
      if (f.collectorUid != null) '${l.dashCollector} : ${f.collectorUid}',
    ].join(' · '),
    generatedOn: l.reportGenerated(fmtDateLocale(locale, DateTime.now())),
    total: l.dashTotal,
    deposits: l.dashDeposits,
    quality: l.dashQuality,
    byMaterial: l.dashByMaterial,
    byCollector: l.dashByCollector,
    lots: l.stockLots,
    material: l.reportMaterial,
    kg: 'kg',
    share: l.reportShare,
    collector: l.dashCollector,
    date: l.reportDate,
    grade: l.reportGrade,
    reference: l.reportReference,
    zones: l.dashZone,
    materialName: (n) => materialLabel(l, materialFromName(n)),
    fmtDate: (d) => fmtDateLocale(locale, d),
  );
}

/// Meilleurs prix d'achat annoncés par un recycleur (écran de dépôt).
String offerSummary(AppLocalizations l, BuildContext c, Purchasing? p) {
  final best =
      (p ?? const {}).entries.where((e) => e.value.accepting && e.value.priceDtPerKg > 0).toList()
        ..sort((a, b) => b.value.priceDtPerKg.compareTo(a.value.priceDtPerKg));
  if (best.isEmpty) return l.offerNone;
  return best
      .take(3)
      .map((e) => '${materialLabel(l, e.key)} ${l.pricePerKg(fmtDt(c, e.value.priceDtPerKg))}')
      .join(' · ');
}

/// Barre horizontale proportionnelle, annotée (dashboard, stock).
class ShareBar extends StatelessWidget {
  const ShareBar({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    return Semantics(
      label: '$label : $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
                  Text(value, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (_, c) => Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: eco.muted.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      height: 12,
                      width: c.maxWidth * fraction.clamp(0, 1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
