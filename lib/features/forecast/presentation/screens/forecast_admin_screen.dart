import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/forecast_providers.dart';
import '../../data/forecast_repository.dart';
import '../../domain/zone_forecast.dart';
import '../widgets/forecast_widgets.dart';

/// Pilotage du modèle de prévision : entraînement, précision (MAPE),
/// alertes, carte de chaleur (US-090 à US-093).
class ForecastAdminScreen extends ConsumerWidget {
  const ForecastAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final runs = ref.watch(forecastRunsProvider).value ?? const <ForecastRun>[];
    final forecasts = ref.watch(forecastsProvider).value ?? const <ZoneForecast>[];
    final state = ref.watch(forecastControllerProvider);
    final last = runs.firstOrNull;
    return LayeredPage(
      header: HeroHeader(
        title: l.forecastAdminTitle,
        subtitle: l.forecastAdminSubtitle,
        emoji: '🧠',
        gradient: EcoGradients.violet,
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                last?.at == null
                    ? l.forecastNeverTrained
                    : l.forecastLastRun(fmtDate(context, last!.at!)),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (last != null)
                Text(
                  '${l.forecastRunRecords(last.records)} · ${triggerLabel(l, last.trigger)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 6),
              Text(l.forecastRetrainHelp, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              EcoButton(
                label: l.forecastRetrain,
                leading: '🔁',
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: () async {
                  final ok = await ref.read(forecastControllerProvider.notifier).retrain();
                  if (context.mounted) {
                    showEcoToast(context, ok ? l.forecastTrained : l.errSaveFailed);
                  }
                },
              ),
              const SizedBox(height: 8),
              EcoButton(
                label: l.heatmapTitle,
                leading: '🗺️',
                style: EcoButtonStyle.ghost,
                onPressed: () => context.go(Routes.heatmap),
              ),
            ],
          ),
        ),
        SectionTitle('🚨 ${l.alertsTitle}'),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: (last?.alerts ?? const []).isEmpty
              ? Padding(padding: const EdgeInsets.all(8), child: Text('✅ ${l.alertsNone}'))
              : Column(
                  children: [
                    for (final (i, a) in last!.alerts.indexed)
                      EcoListTile(
                        leading: EcoAvatar(
                          text: a.kind == AlertKind.overload ? '🔥' : '🕳️',
                          gradient: a.kind == AlertKind.overload
                              ? EcoGradients.coral
                              : EcoGradients.sun,
                        ),
                        title:
                            '${a.zoneName} · ${a.kind == AlertKind.overload ? l.alertOverload : l.alertUnder}',
                        subtitle: a.kind == AlertKind.overload
                            ? l.alertOverloadBody(
                                l.kg(fmtKg(context, a.forecastKg)),
                                l.kg(fmtKg(context, a.capacityKg)),
                              )
                            : a.capacityKg == 0
                            ? l.alertNoCollector(l.kg(fmtKg(context, a.forecastKg)))
                            : l.alertUnderBody(pct(a.unmatchedRatio)),
                        showDivider: i < last.alerts.length - 1,
                      ),
                  ],
                ),
        ),
        SectionTitle('🎯 ${l.forecastAccuracy}'),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: forecasts.isEmpty
              ? Padding(padding: const EdgeInsets.all(8), child: Text(l.forecastNone))
              : Column(
                  children: [
                    for (final (i, f) in forecasts.indexed)
                      EcoListTile(
                        leading: EcoAvatar(text: groupEmoji(MaterialGroup.plastic)),
                        title: f.zoneName,
                        subtitle: [
                          'MAPE ${f.mape == null ? '—' : pct(f.mape!)}',
                          'WAPE ${f.wape == null ? '—' : pct(f.wape!)}',
                          l.forecastHistory(f.samples),
                          forecastMethodLabel(l, f.method),
                        ].join(' · '),
                        trailing: EcoChip(
                          label: mapeQuality(l, f.mape).label,
                          tone: mapeQuality(l, f.mape).tone,
                        ),
                        showDivider: i < forecasts.length - 1,
                      ),
                  ],
                ),
        ),
        if (runs.length > 1) ...[
          SectionTitle('🕒 ${l.forecastRuns}'),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, r) in runs.take(10).indexed)
                  EcoListTile(
                    leading: EcoAvatar(
                      text: switch (r.trigger) {
                        'auto' => '⏱️',
                        'scheduled' => '🌙',
                        _ => '🔁',
                      },
                    ),
                    title: r.at == null ? '—' : fmtDate(context, r.at!),
                    subtitle:
                        '${l.forecastRunRecords(r.records)} · MAPE ${r.mape == null ? '—' : pct(r.mape!)}',
                    showDivider: i < runs.take(10).length - 1,
                  ),
              ],
            ),
          ),
        ],
        EcoCard(child: Text('ℹ️ ${l.mapeExplain}')),
      ],
    );
  }
}

String triggerLabel(AppLocalizations l, String trigger) => switch (trigger) {
  'auto' => l.forecastAuto,
  'scheduled' => l.forecastScheduled,
  _ => l.forecastManual,
};
