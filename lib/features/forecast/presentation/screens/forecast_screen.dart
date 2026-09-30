import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/forecast_providers.dart';
import '../../domain/forecast_model.dart';
import '../../domain/zone_forecast.dart';
import '../widgets/forecast_widgets.dart';

/// Prévision des volumes par zone à 7 et 30 jours (US-088).
class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  String? _zone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(forecastsProvider).value ?? const <ZoneForecast>[];
    final now = ref.watch(clockProvider)();
    final selected = all.where((f) => f.zoneId == _zone).firstOrNull ?? all.firstOrNull;
    return LayeredPage(
      header: HeroHeader(
        title: l.forecastTitle,
        subtitle: l.forecastSubtitle,
        emoji: '🔮',
        gradient: EcoGradients.violet,
      ),
      children: [
        if (all.isEmpty) EcoCard(child: Text(l.forecastNone)),
        if (all.isNotEmpty) ...[
          PlasticForecastCard(forecasts: all),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in all)
                EcoChip(
                  label: f.zoneName,
                  selected: f.zoneId == selected?.zoneId,
                  onTap: () => setState(() => _zone = f.zoneId),
                ),
            ],
          ),
        ],
        if (selected != null) ...[
          SectionTitle('📍 ${selected.zoneName}'),
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selected.plastic case final p?) ...[
                  Text(l.forecastPlasticDaily, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ForecastBars(values: p.daily, start: dayOf(now)),
                  const SizedBox(height: 6),
                  Text(
                    l.forecastRange(fmtKg(context, p.low7), fmtKg(context, p.high7)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 24),
                ],
                for (final g in MaterialGroup.values)
                  if (selected.groups[g] case final f?) GroupForecastTile(group: g, forecast: f),
              ],
            ),
          ),
          EcoCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                EcoChip(
                  label: '🧠 ${forecastMethodLabel(l, selected.method)}',
                  tone: ChipTone.violet,
                ),
                EcoChip(label: l.forecastHistory(selected.samples), tone: ChipTone.sky),
                EcoChip(
                  label:
                      '${l.forecastAccuracy} : ${selected.mape == null ? '—' : pct(selected.mape!)} · ${mapeQuality(l, selected.mape).label}',
                  tone: mapeQuality(l, selected.mape).tone,
                ),
                if (selected.trainedAt != null)
                  EcoChip(
                    label: l.forecastTrainedOn(fmtDate(context, selected.trainedAt!)),
                    tone: ChipTone.sun,
                  ),
              ],
            ),
          ),
          EcoCard(child: Text('ℹ️ ${l.forecastExplain}')),
        ],
      ],
    );
  }
}
