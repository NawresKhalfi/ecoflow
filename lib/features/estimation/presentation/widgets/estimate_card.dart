import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/estimate_draft_controller.dart';
import '../../application/estimation_providers.dart';
import '../../domain/estimate.dart';
import '../../domain/estimation_coefficients.dart';
import '../../domain/handover_code.dart';
import 'estimation_format.dart';

/// Estimation du poids et de la valeur du scan (US-023 à US-026).
class EstimateSection extends ConsumerWidget {
  const EstimateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final estimate = ref.watch(draftEstimateProvider);
    final draft = ref.watch(estimateDraftControllerProvider);
    final ctrl = ref.read(estimateDraftControllerProvider.notifier);
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final scale = ref.watch(activePriceScaleProvider);
    if (estimate == null || estimate.isEmpty) return const SizedBox.shrink();
    final saved = draft.savedCode != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('⚖️ ${l.estTitle}', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  EcoChip(label: l.estBadge, tone: ChipTone.sun),
                ],
              ),
              const SizedBox(height: 6),
              for (final (i, line) in estimate.lines.indexed)
                _LineRow(
                  line: line,
                  category: categoryById(catalog, line.categoryId),
                  manual: draft.manualKg[line.categoryId],
                  enabled: !saved,
                  last: i == estimate.lines.length - 1,
                  onManual: (v) => ctrl.setManualKg(line.categoryId, v),
                ),
              const SizedBox(height: 12),
              Text(l.estContainer, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  EcoChip(
                    label: l.estContainerNone,
                    selected: draft.container == null,
                    onTap: saved ? null : () => ctrl.setContainer(null),
                  ),
                  for (final c in WasteContainer.values)
                    EcoChip(
                      label: containerLabel(l, c),
                      selected: draft.container == c,
                      onTap: saved ? null : () => ctrl.setContainer(c),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _TotalCard(estimate: estimate, scaleDate: fmtDate(context, scale.effectiveFrom)),
        if (estimate.needsConfirmation && !draft.confirmed && !saved) ...[
          const SizedBox(height: 16),
          EcoCard(
            gradient: EcoGradients.sun,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '⚠️ ${l.estLowConfidence}',
                  style: AppTheme.weighted(15, 600, color: EcoColors.onSun),
                ),
                const SizedBox(height: 10),
                EcoButton(
                  label: l.estConfirm,
                  style: EcoButtonStyle.ghost,
                  onPressed: ctrl.confirm,
                ),
              ],
            ),
          ),
        ],
        if (draft.error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(failureText(context, draft.error!)),
        ],
        const SizedBox(height: 16),
        if (saved)
          _CodeCard(code: draft.savedCode!)
        else
          EcoButton(
            label: l.estSave,
            leading: '🧾',
            style: EcoButtonStyle.green,
            loading: draft.saving,
            onPressed: estimate.needsConfirmation && !draft.confirmed ? null : ctrl.save,
          ),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.category,
    required this.manual,
    required this.enabled,
    required this.last,
    required this.onManual,
  });

  final EstimateLine line;
  final WasteCategory category;
  final double? manual;
  final bool enabled;
  final bool last;
  final ValueChanged<double?> onManual;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: context.eco.line)),
      ),
      child: Row(
        children: [
          EcoAvatar(text: category.emoji, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.name(languageOf(context)), style: text.titleSmall),
                Text(
                  '${l.approxKg(fmtKg(context, line.kg))} · ${l.approxDt(fmtDt(context, line.valueDt))}',
                  style: text.bodyMedium,
                ),
                Text(
                  '${methodLabel(l, line.method)} · ${l.pricePerKg(fmtDt(context, line.priceDtPerKg))}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 96,
            child: TextFormField(
              key: ValueKey('manual-${line.categoryId}'),
              initialValue: manual == null ? '' : '$manual',
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'kg',
                hintText: l.estManualHint,
                isDense: true,
              ),
              onChanged: (v) => onManual(parseKg(v)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.estimate, required this.scaleDate});

  final Estimate estimate;
  final String scaleDate;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final white = Colors.white.withValues(alpha: .9);
    return EcoCard(
      gradient: EcoGradients.green,
      decorated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.estTotal, style: AppTheme.weighted(14, 700, color: white)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 18,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                l.approxKg(fmtKg(context, estimate.totalKg)),
                style: AppTheme.weighted(30, 800, color: Colors.white),
              ),
              Text(
                l.approxDt(fmtDt(context, estimate.totalDt)),
                style: AppTheme.weighted(30, 800, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l.estReliability, style: AppTheme.weighted(13, 600, color: white)),
              EcoChip(
                label: l.percent((estimate.confidence * 100).round()),
                tone: estimate.needsConfirmation ? ChipTone.coral : ChipTone.green,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${l.estFinalAfterWeighing} ${l.estScaleOf(scaleDate)}.',
            style: AppTheme.weighted(13, 500, color: white),
          ),
        ],
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EcoCard(
      gradient: EcoGradients.violet,
      decorated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔑 ${l.estCodeTitle}', style: AppTheme.weighted(15, 700, color: Colors.white)),
          const SizedBox(height: 4),
          SelectableText(
            formatHandoverCode(code),
            style: AppTheme.weighted(34, 800, color: Colors.white, letterSpacing: 4),
          ),
          const SizedBox(height: 4),
          Text(
            l.estCodeHelp,
            style: AppTheme.weighted(14, 500, color: Colors.white.withValues(alpha: .92)),
          ),
          const SizedBox(height: 12),
          EcoButton(
            label: l.collectRequestCta,
            leading: '🚚',
            style: EcoButtonStyle.ghost,
            onPressed: () => context.go(Routes.collectionNew(code)),
          ),
        ],
      ),
    );
  }
}
