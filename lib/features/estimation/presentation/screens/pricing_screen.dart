import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../../core/firebase/firebase_providers.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/estimation_admin_controllers.dart';
import '../../application/estimation_providers.dart';
import '../widgets/estimation_format.dart';
import '../widgets/price_scale_form.dart';

/// Barème des prix (US-027) et précision des estimations (US-030).
class PricingScreen extends ConsumerWidget {
  const PricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final scales = ref.watch(priceScalesProvider).value ?? const [];
    final active = ref.watch(activePriceScaleProvider);
    final now = ref.watch(clockProvider)();
    final white = Colors.white.withValues(alpha: .9);
    return LayeredPage(
      header: HeroHeader(
        title: l.pricingTitle,
        subtitle: l.pricingSubtitle,
        emoji: '💰',
        gradient: EcoGradients.sun,
      ),
      children: [
        EcoCard(
          gradient: EcoGradients.green,
          decorated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                active.id == 'default'
                    ? l.pricingDefault
                    : '${l.pricingActive} · ${fmtDate(context, active.effectiveFrom)}',
                style: AppTheme.weighted(15, 700, color: white),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in RecyclableMaterial.values)
                    EcoChip(
                      label:
                          '${materialLabel(l, m)} · ${l.pricePerKg(fmtDt(context, active.priceOf(m)))}',
                    ),
                ],
              ),
            ],
          ),
        ),
        EcoButton(
          label: l.pricingNew,
          leading: '➕',
          onPressed: () => showPriceScaleForm(context, active),
        ),
        if (scales.isNotEmpty) ...[
          SectionTitle(l.pricingHistory),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, s) in scales.indexed)
                  EcoListTile(
                    showDivider: i < scales.length - 1,
                    leading: EcoAvatar(
                      text: s.id == active.id ? '✅' : (s.effectiveFrom.isAfter(now) ? '🕒' : '📄'),
                    ),
                    title: fmtDate(context, s.effectiveFrom),
                    subtitle: [
                      '${l.matPet} ${fmtDt(context, s.priceOf(RecyclableMaterial.pet))} · '
                          '${l.matAluminium} ${fmtDt(context, s.priceOf(RecyclableMaterial.aluminium))} DT/kg',
                      if (s.note.isNotEmpty) s.note,
                    ].join('\n'),
                    trailing: s.id == active.id
                        ? EcoChip(label: l.pricingActive)
                        : (s.effectiveFrom.isAfter(now)
                              ? EcoChip(label: l.pricingUpcoming, tone: ChipTone.sky)
                              : null),
                  ),
              ],
            ),
          ),
        ],
        const _CalibrationCard(),
      ],
    );
  }
}

class _CalibrationCard extends ConsumerWidget {
  const _CalibrationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(calibrationControllerProvider);
    final ctrl = ref.read(calibrationControllerProvider.notifier);
    final report = ctrl.report;
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🎯 ${l.calibTitle}', style: Theme.of(context).textTheme.titleMedium),
          Text(l.calibBody, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          if (report != null && report.errors.isEmpty) Text(l.calibNoData),
          if (report != null)
            for (final e in report.errors)
              EcoListTile(
                leading: EcoAvatar(text: categoryById(catalog, e.categoryId).emoji, size: 40),
                title: categoryById(catalog, e.categoryId).name(languageOf(context)),
                subtitle:
                    '${l.calibSamples(e.samples)} · ${l.calibMae} ${l.kg(fmtKg(context, e.maeKg))}',
                trailing: EcoChip(
                  label: '${l.calibRatio} ${e.ratio.toStringAsFixed(2)}',
                  tone: (e.ratio - 1).abs() <= .1 ? ChipTone.green : ChipTone.coral,
                ),
              ),
          const SizedBox(height: 10),
          EcoButton(
            label: l.calibAnalyze,
            leading: '🔍',
            style: EcoButtonStyle.ghost,
            loading: state.isLoading,
            onPressed: ctrl.analyze,
          ),
          if (report != null && report.errors.isNotEmpty) ...[
            const SizedBox(height: 10),
            EcoButton(
              label: l.calibApply(report.proposed.version),
              leading: '✅',
              style: EcoButtonStyle.green,
              onPressed: () async {
                if (await ctrl.apply() && context.mounted) showEcoToast(context, l.calibApplied);
              },
            ),
          ],
        ],
      ),
    );
  }
}
