import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/application/profile_providers.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../forecast/application/forecast_providers.dart';
import '../../../forecast/domain/zone_forecast.dart';
import '../../../forecast/presentation/widgets/forecast_widgets.dart';
import '../../application/recycler_providers.dart';
import '../../domain/analytics.dart';
import '../../domain/stock.dart';
import '../widgets/recycler_labels.dart';
import '../widgets/weekly_bars.dart';

/// Dashboard des approvisionnements du recycleur (US-079, US-082, US-083).
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lots = ref.watch(myLotsProvider).value ?? const <StockLot>[];
    final f = ref.watch(dashboardFilterProvider);
    final setF = ref.read(dashboardFilterProvider.notifier).set;
    final r = ref.watch(supplyReportProvider);
    final choices = filterChoices(lots);
    final state = ref.watch(recyclerControllerProvider);
    final company = ref.watch(companyProfileProvider).value?.legalName ?? '';
    final stock = stockSummary(lots);
    Future<void> export({required bool pdf}) async {
      final labels = reportLabels(context, company: company, f: f);
      final ok = await ref.read(recyclerControllerProvider.notifier).export(r, labels, pdf: pdf);
      if (!ok && context.mounted) showEcoToast(context, l.errSaveFailed);
    }

    return LayeredPage(
      header: HeroHeader(
        title: l.dashTitle,
        subtitle: l.dashSubtitle,
        emoji: '📊',
        gradient: EcoGradients.sky,
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in ReportPeriod.values)
                    EcoChip(
                      label: periodLabel(l, p),
                      selected: f.period == p,
                      onTap: () => setF(f.copyWith(period: p)),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // Empilés : sur téléphone, côte à côte, les libellés sont tronqués.
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: f.zoneId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.dashZone),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.dashAllZones)),
                      for (final z in choices.zones.toList()..sort())
                        DropdownMenuItem(value: z, child: Text(zoneLabel(z))),
                    ],
                    onChanged: (v) => setF(f.copyWith(zoneId: () => v)),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: f.collectorUid,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.dashCollector),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.dashAllCollectors)),
                      for (final e in choices.collectors.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setF(f.copyWith(collectorUid: () => v)),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            Expanded(
              child: StatTile(emoji: '⚖️', value: fmtKg(context, r.totalKg), label: l.dashTotalKg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                emoji: '🚚',
                value: '${r.deposits}',
                label: l.dashDeposits,
                gradient: EcoGradients.sky,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                emoji: '✅',
                value: r.lots.isEmpty ? '—' : '${(r.quality * 100).round()} %',
                label: l.dashQuality,
                gradient: EcoGradients.violet,
              ),
            ),
          ],
        ),
        // Prévisions intégrées au dashboard (US-089), selon la zone filtrée.
        PlasticForecastCard(
          forecasts: [
            for (final z in ref.watch(forecastsProvider).value ?? const <ZoneForecast>[])
              if (f.zoneId == null || z.zoneId == f.zoneId) z,
          ],
          onTap: () => context.go(Routes.forecast),
        ),
        SectionTitle('♻️ ${l.dashByMaterial}'),
        EcoCard(
          child: r.byMaterial.isEmpty
              ? Text(l.dashEmpty)
              : Column(
                  children: [
                    for (final e in r.ranked)
                      ShareBar(
                        label: '${materialEmoji(e.key)} ${materialLabel(l, e.key)}',
                        value:
                            '${l.kg(fmtKg(context, e.value))} · ${(e.value / r.totalKg * 100).round()} %',
                        fraction: e.value / r.ranked.first.value,
                        color: materialColor(e.key),
                      ),
                  ],
                ),
        ),
        if (r.lots.isNotEmpty) ...[
          SectionTitle('📈 ${l.dashWeekly}'),
          EcoCard(child: WeeklyBars(values: r.weekly)),
          SectionTitle('🚚 ${l.dashByCollector}'),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, c)
                    in (r.byCollector.values.toList()..sort((a, b) => b.kg.compareTo(a.kg)))
                        .take(5)
                        .indexed)
                  EcoListTile(
                    leading: EcoAvatar(text: c.name.isEmpty ? '?' : c.name[0]),
                    title: c.name,
                    trailing: Text(l.kg(fmtKg(context, c.kg))),
                    showDivider: i < r.byCollector.length - 1 && i < 4,
                  ),
              ],
            ),
          ),
        ],
        SectionTitle('📦 ${l.stockTitle}'),
        EcoCard(
          onTap: () => context.go(Routes.stock),
          child: stock.isEmpty
              ? Text(l.stockEmpty)
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in stock.entries)
                      EcoChip(
                        label:
                            '${materialEmoji(e.key)} ${materialLabel(l, e.key)} · ${l.kg(fmtKg(context, totalKg(e.value)))}',
                      ),
                  ],
                ),
        ),
        ResponsiveGrid(
          children: [
            EcoButton(
              label: l.exportPdf,
              leading: '📄',
              loading: state.isLoading,
              onPressed: r.lots.isEmpty ? null : () => export(pdf: true),
            ),
            EcoButton(
              label: l.exportExcel,
              leading: '📗',
              style: EcoButtonStyle.ghost,
              loading: state.isLoading,
              onPressed: r.lots.isEmpty ? null : () => export(pdf: false),
            ),
          ],
        ),
      ],
    );
  }
}
