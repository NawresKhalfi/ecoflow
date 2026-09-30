import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../recycler/domain/stock.dart';
import '../../../recycler/presentation/widgets/reception_sheet.dart';
import '../../../recycler/presentation/widgets/recycler_labels.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/collector_controllers.dart';
import '../../application/missions_providers.dart';
import '../../domain/deposit.dart';
import '../widgets/mission_labels.dart';

/// Réception des lots livrés par les collecteurs (US-055, US-080, US-086) :
/// lots en route, réception avec contrôle qualité, historique.
class ReceptionsScreen extends ConsumerWidget {
  const ReceptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final deposits = ref.watch(incomingDepositsProvider).value ?? const <Deposit>[];
    final ctrl = ref.read(depositControllerProvider.notifier);
    ref.watch(depositControllerProvider);
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final pending = deposits.where((d) => d.status == DepositStatus.pending).toList();
    final done = deposits.where((d) => d.status != DepositStatus.pending).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));

    Widget categories(Deposit d) => Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in d.byCategoryKg.entries)
          EcoChip(
            label:
                '${categoryById(catalog, e.key).emoji} ${categoryById(catalog, e.key).name(languageOf(context))} · ${l.kg(fmtKg(context, e.value))}',
          ),
      ],
    );

    return LayeredPage(
      header: HeroHeader(
        title: l.receptionsTitle,
        subtitle: l.receptionsSubtitle,
        emoji: '📥',
        gradient: EcoGradients.sky,
      ),
      children: [
        if (deposits.isEmpty) EcoCard(child: Text(l.receptionsEmpty)),
        if (pending.isNotEmpty) SectionTitle('🚚 ${l.receptionsIncoming(pending.length)}'),
        for (final d in pending)
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
                    EcoChip(label: depositLabel(l, d.status), tone: ChipTone.sun),
                  ],
                ),
                Text(
                  [
                    d.collectorName ?? '—',
                    if (d.createdAt != null) fmtDate(context, d.createdAt!),
                    l.receptionMissions(d.missionIds.length),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                categories(d),
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
                        label: l.receiveAction,
                        style: EcoButtonStyle.green,
                        onPressed: () async {
                          final ok = await showReceptionSheet(context, d, catalog);
                          if (ok == true && context.mounted) showEcoToast(context, l.receiveDone);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        if (done.isNotEmpty) SectionTitle('🗂️ ${l.receptionsHistory}'),
        for (final d in done)
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.kg(fmtKg(context, d.receivedKg.isEmpty ? d.totalKg : d.receivedTotalKg)),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    EcoChip(
                      label: depositLabel(l, d.status),
                      tone: d.status == DepositStatus.confirmed ? ChipTone.green : ChipTone.coral,
                    ),
                  ],
                ),
                Text(
                  [
                    d.collectorName ?? '—',
                    if (d.createdAt != null) fmtDate(context, d.createdAt!),
                    if (d.quality != null)
                      gradeLabel(
                        l,
                        QualityGrade.values.firstWhere(
                          (g) => g.name == d.quality,
                          orElse: () => QualityGrade.b,
                        ),
                      ),
                    if ((d.contaminationPct ?? 0) > 0)
                      l.receptionContam(d.contaminationPct!.round()),
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (d.receivedKg.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in d.receivedKg.entries.where((e) => e.value > 0))
                        EcoChip(
                          tone: ChipTone.sky,
                          label:
                              '${materialEmoji(materialFromName(e.key))} ${materialLabel(l, materialFromName(e.key))} · ${l.kg(fmtKg(context, e.value))}',
                        ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 6),
                  categories(d),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
