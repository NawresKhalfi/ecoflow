import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../domain/forecast_model.dart';
import '../../domain/zone_forecast.dart';

String groupLabel(AppLocalizations l, MaterialGroup g) => switch (g) {
  MaterialGroup.plastic => l.groupPlastic,
  MaterialGroup.cardboard => l.groupCardboard,
  MaterialGroup.metal => l.groupMetal,
  MaterialGroup.glass => l.groupGlass,
  MaterialGroup.other => l.groupOther,
};

String groupEmoji(MaterialGroup g) => switch (g) {
  MaterialGroup.plastic => '🧴',
  MaterialGroup.cardboard => '📦',
  MaterialGroup.metal => '🥫',
  MaterialGroup.glass => '🍾',
  MaterialGroup.other => '♻️',
};

String forecastMethodLabel(AppLocalizations l, ForecastMethod m) => switch (m) {
  ForecastMethod.holtWinters => l.methodHoltWinters,
  ForecastMethod.movingAverage => l.methodMovingAverage,
  ForecastMethod.none => l.methodNone,
};

String pct(double v) => '${(v * 100).round()} %';

/// Qualité d'un MAPE (US-092) : < 20 % bonne, < 40 % moyenne, sinon faible.
({String label, ChipTone tone}) mapeQuality(AppLocalizations l, double? mape) => mape == null
    ? (label: l.mapeUnknown, tone: ChipTone.sky)
    : mape < .2
    ? (label: l.mapeGood, tone: ChipTone.green)
    : mape < .4
    ? (label: l.mapeFair, tone: ChipTone.sun)
    : (label: l.mapePoor, tone: ChipTone.coral);

/// Prévision d'une famille : 7 et 30 jours, intervalle, tendance (US-088).
class GroupForecastTile extends StatelessWidget {
  const GroupForecastTile({super.key, required this.group, required this.forecast});
  final MaterialGroup group;
  final GroupForecast forecast;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = forecast.trend7;
    return EcoListTile(
      leading: EcoAvatar(text: groupEmoji(group)),
      title: groupLabel(l, group),
      subtitle: [
        l.forecast7(l.kg(fmtKg(context, forecast.next7))),
        l.forecast30(l.kg(fmtKg(context, forecast.next30))),
        if (t != null) '${t >= 0 ? '↗' : '↘'} ${t >= 0 ? '+' : ''}${pct(t)}',
      ].join(' · '),
      showDivider: false,
    );
  }
}

/// Carte de synthèse « plastique à venir » pour le dashboard (US-089).
class PlasticForecastCard extends StatelessWidget {
  const PlasticForecastCard({super.key, required this.forecasts, this.onTap});
  final List<ZoneForecast> forecasts;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = [for (final f in forecasts) ?f.plastic];
    final n7 = p.fold(0.0, (s, g) => s + g.next7);
    final n30 = p.fold(0.0, (s, g) => s + g.next30);
    final low = p.fold(0.0, (s, g) => s + g.low7);
    final high = p.fold(0.0, (s, g) => s + g.high7);
    final last7 = p.fold(0.0, (s, g) => s + g.last7);
    final white = Colors.white.withValues(alpha: .92);
    return EcoCard(
      gradient: EcoGradients.violet,
      decorated: true,
      onTap: onTap,
      semanticLabel: l.forecastPlasticSemantics(
        l.kg(fmtKg(context, n7)),
        l.kg(fmtKg(context, n30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🔮 ${l.forecastPlasticTitle}', style: AppTheme.weighted(16, 700, color: white)),
          const SizedBox(height: 8),
          if (p.isEmpty)
            Text(l.forecastNone, style: AppTheme.weighted(14, 500, color: white))
          else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.kg(fmtKg(context, n7)),
                        style: AppTheme.weighted(28, 800, color: Colors.white),
                      ),
                      Text(l.next7Days, style: AppTheme.weighted(13, 600, color: white)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.kg(fmtKg(context, n30)),
                        style: AppTheme.weighted(28, 800, color: Colors.white),
                      ),
                      Text(l.next30Days, style: AppTheme.weighted(13, 600, color: white)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              [
                l.forecastRange(fmtKg(context, low), fmtKg(context, high)),
                if (last7 > 0) l.forecastVsLast(pct((n7 - last7) / last7)),
              ].join(' · '),
              style: AppTheme.weighted(13, 500, color: white),
            ),
          ],
        ],
      ),
    );
  }
}

/// Prévision jour par jour (14 jours), une barre par jour.
class ForecastBars extends StatelessWidget {
  const ForecastBars({super.key, required this.values, required this.start, this.height = 110});

  final List<double> values;
  final DateTime start;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eco = context.eco;
    final lang = Localizations.localeOf(context).languageCode;
    final max = values.fold(0.0, (a, b) => b > a ? b : a);
    return Semantics(
      label: l.forecastDailySemantics(
        values.length,
        l.kg(fmtKg(context, values.fold(0.0, (a, b) => a + b))),
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height + 22,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, v) in values.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: max == 0 ? 2 : (v / max * height).clamp(2, height),
                          decoration: BoxDecoration(
                            color: EcoColors.violet.withValues(alpha: i < 7 ? .9 : .45),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          child: Text(
                            DateFormat.E(
                              lang,
                            ).format(start.add(Duration(days: i))).substring(0, 1).toUpperCase(),
                            style: TextStyle(fontSize: 10, color: eco.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
