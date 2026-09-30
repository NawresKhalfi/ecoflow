import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/collector_controllers.dart';
import '../../application/missions_providers.dart';
import '../../domain/deposit.dart';
import '../widgets/mission_labels.dart';

/// Confirmation des dépôts par le recycleur (US-055 ; réception complète
/// avec contrôle qualité : US-080, epic 9).
class ReceptionsScreen extends ConsumerWidget {
  const ReceptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final deposits = ref.watch(incomingDepositsProvider).value ?? const [];
    final ctrl = ref.read(depositControllerProvider.notifier);
    ref.watch(depositControllerProvider);
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    return LayeredPage(
      header: HeroHeader(
        title: l.receptionsTitle,
        subtitle: l.receptionsSubtitle,
        emoji: '📥',
        gradient: EcoGradients.sky,
      ),
      children: [
        if (deposits.isEmpty) EcoCard(child: Text(l.receptionsEmpty)),
        for (final d in deposits)
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.kg(fmtKg(context, d.totalKg)),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    EcoChip(
                      label: depositLabel(l, d.status),
                      tone: d.status == DepositStatus.pending ? ChipTone.sun : ChipTone.green,
                    ),
                  ],
                ),
                if (d.createdAt != null)
                  Text(
                    fmtDate(context, d.createdAt!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in d.byCategoryKg.entries)
                      EcoChip(
                        label:
                            '${categoryById(catalog, e.key).emoji} ${categoryById(catalog, e.key).name(languageOf(context))} · ${l.kg(fmtKg(context, e.value))}',
                      ),
                  ],
                ),
                if (d.status == DepositStatus.pending) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: EcoButton(
                          label: l.receptionReject,
                          style: EcoButtonStyle.ghost,
                          onPressed: () => ctrl.review(d, confirmed: false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: EcoButton(
                          label: l.receptionConfirm,
                          style: EcoButtonStyle.green,
                          onPressed: () => ctrl.review(d, confirmed: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
