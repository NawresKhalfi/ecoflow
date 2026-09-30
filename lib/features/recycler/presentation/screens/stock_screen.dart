import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../application/recycler_providers.dart';
import '../../domain/stock.dart';
import '../widgets/recycler_labels.dart';
import '../widgets/stock_sheets.dart';

/// Stock par matière et par qualité, lots et production (US-081, US-087).
class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  RecyclableMaterial? _material;
  bool _showEmpty = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lots = ref.watch(myLotsProvider).value ?? const <StockLot>[];
    final summary = stockSummary(lots);
    final max = summary.values.map(totalKg).fold(0.0, (a, b) => b > a ? b : a);
    final shown = lots
        .where((x) => (_showEmpty || x.inStock) && (_material == null || x.material == _material))
        .toList();
    return LayeredPage(
      header: HeroHeader(
        title: l.stockTitle,
        subtitle: l.stockSubtitle,
        emoji: '📦',
        gradient: EcoGradients.green,
      ),
      children: [
        EcoCard(
          child: summary.isEmpty
              ? Text(l.stockEmpty)
              : Column(
                  children: [
                    for (final e
                        in (summary.entries.toList()
                          ..sort((a, b) => totalKg(b.value).compareTo(totalKg(a.value)))))
                      ShareBar(
                        label: '${materialEmoji(e.key)} ${materialLabel(l, e.key)}',
                        value: [
                          l.kg(fmtKg(context, totalKg(e.value))),
                          for (final g in QualityGrade.values)
                            if ((e.value[g] ?? 0) > 0)
                              '${g.name.toUpperCase()} ${fmtKg(context, e.value[g]!)}',
                        ].join(' · '),
                        fraction: max == 0 ? 0 : totalKg(e.value) / max,
                        color: materialColor(e.key),
                      ),
                  ],
                ),
        ),
        EcoButton(
          label: l.productionTitle,
          leading: '🏭',
          onPressed: summary.isEmpty
              ? null
              : () async {
                  final ok = await showProductionSheet(context, lots);
                  if (ok == true && context.mounted) showEcoToast(context, l.productionDone);
                },
        ),
        SectionTitle('🏷️ ${l.stockLots}'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            EcoChip(
              label: l.dashAllMaterials,
              selected: _material == null,
              onTap: () => setState(() => _material = null),
            ),
            for (final m in {for (final x in lots) x.material})
              EcoChip(
                label: '${materialEmoji(m)} ${materialLabel(l, m)}',
                selected: _material == m,
                onTap: () => setState(() => _material = m),
              ),
            EcoChip(
              label: l.stockShowEmpty,
              tone: ChipTone.sky,
              selected: _showEmpty,
              onTap: () => setState(() => _showEmpty = !_showEmpty),
            ),
          ],
        ),
        if (shown.isEmpty) EcoCard(child: Text(l.stockNoLot)),
        if (shown.isNotEmpty)
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, x) in shown.indexed)
                  EcoListTile(
                    leading: EcoAvatar(text: materialEmoji(x.material)),
                    title: '${x.reference} · ${materialLabel(l, x.material)}',
                    subtitle: [
                      formLabel(l, x.form),
                      gradeLabel(l, x.grade),
                      if (x.receivedAt != null) fmtDate(context, x.receivedAt!),
                      if (x.marketplace) '🛒',
                    ].join(' · '),
                    trailing: Text(
                      x.inStock ? l.kg(fmtKg(context, x.kg)) : l.stockDepleted,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    onTap: () => context.go(Routes.lotDetail(x.id)),
                    showDivider: i < shown.length - 1,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
