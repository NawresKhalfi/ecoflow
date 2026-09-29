import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../application/estimation_providers.dart';
import '../../domain/estimate_record.dart';
import '../../domain/handover_code.dart';
import '../widgets/comparison_table.dart';
import '../widgets/estimation_format.dart';

/// Estimations du citoyen et montant final après pesée (US-029).
class EstimatesScreen extends ConsumerWidget {
  const EstimatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final list = ref.watch(myEstimatesProvider).value ?? const [];
    return LayeredPage(
      header: HeroHeader(
        title: l.estimatesTitle,
        subtitle: l.estimatesSubtitle,
        emoji: '🧾',
        gradient: EcoGradients.violet,
      ),
      children: [
        if (list.isEmpty)
          EcoCard(
            onTap: () => context.go(Routes.scan),
            child: Row(
              children: [
                const EcoAvatar(text: '📸', gradient: EcoGradients.coral),
                const SizedBox(width: 14),
                Expanded(child: Text(l.estimatesEmpty)),
              ],
            ),
          )
        else
          ResponsiveGrid(children: [for (final r in list) _EstimateTile(record: r)]),
      ],
    );
  }
}

class _EstimateTile extends StatelessWidget {
  const _EstimateTile({required this.record});
  final EstimateRecord record;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = record.weighing;
    return EcoCard(
      onTap: () => context.go(Routes.estimateDetail(record.code)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatHandoverCode(record.code),
                  style: AppTheme.weighted(18, 800, color: context.eco.ink, letterSpacing: 2),
                ),
              ),
              EcoChip(
                label: record.isWeighed ? '✓ ${l.estStatusWeighed}' : '⏳ ${l.estStatusPending}',
                tone: record.isWeighed ? ChipTone.green : ChipTone.sun,
              ),
            ],
          ),
          if (record.createdAt != null)
            Text(fmtDate(context, record.createdAt!), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            w == null
                ? '${l.approxKg(fmtKg(context, record.estimate.totalKg))} · ${l.approxDt(fmtDt(context, record.estimate.totalDt))}'
                : '${l.kg(fmtKg(context, w.actualKg))} · ${l.estFinalAmount} ${l.dt(fmtDt(context, w.finalDt))}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

/// Détail d'une estimation : code, puis comparatif après pesée.
class EstimateDetailScreen extends ConsumerWidget {
  const EstimateDetailScreen({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final record = ref.watch(estimateByCodeProvider(code)).value;
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final w = record?.weighing;
    return LayeredPage(
      header: HeroHeader(
        title: formatHandoverCode(code),
        subtitle: record == null ? null : (record.isWeighed ? l.estStatusWeighed : l.estCodeHelp),
        emoji: record?.isWeighed == true ? '✅' : '⚖️',
        gradient: record?.isWeighed == true ? EcoGradients.green : EcoGradients.violet,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.estimates),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        if (record != null)
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  w == null ? '⚖️ ${l.estTitle}' : '📊 ${l.estCompareTitle}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                ComparisonTable(
                  // Avant pesée : l'estimation seule (réel = estimé masqué).
                  result: w ?? record.estimateAsPending,
                  catalog: catalog,
                  pending: w == null,
                ),
              ],
            ),
          ),
        if (record != null && record.requestId != null)
          EcoButton(
            label: l.navCollections,
            leading: '🚚',
            style: EcoButtonStyle.ghost,
            onPressed: () => context.go(Routes.collectionDetail(record.requestId!)),
          )
        else if (record != null && !record.isWeighed)
          EcoButton(
            label: l.collectRequestCta,
            leading: '🚚',
            onPressed: () => context.go(Routes.collectionNew(record.code)),
          ),
      ],
    );
  }
}
