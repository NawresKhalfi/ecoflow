import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/application/collection_providers.dart';
import '../../../collection/presentation/widgets/location_picker.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/forecast_providers.dart';
import '../../domain/zone_forecast.dart';

/// Rampe séquentielle (une teinte, clair → foncé) de l'intensité.
Color heatColor(double t) =>
    Color.lerp(const Color(0xFFFFE08A), const Color(0xFFC4482A), t.clamp(0, 1))!;

/// Carte de chaleur des zones à fort potentiel (US-090) : collectes pesées
/// des 90 derniers jours agrégées par cellule d'environ 1 km.
class HeatmapScreen extends ConsumerWidget {
  const HeatmapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final records = ref.watch(volumeRecordsProvider);
    final zones = ref.watch(collectionConfigProvider).value?.zones ?? const [];
    final forecasts = {
      for (final f in ref.watch(forecastsProvider).value ?? const <ZoneForecast>[]) f.zoneId: f,
    };
    final since = DateTime.now().subtract(const Duration(days: 90));
    final cells = heatCells([...?records.value?.where((r) => r.day.isAfter(since))]);
    final maxKg = cells.fold(0.0, (m, c) => max(m, c.kg));
    final tiles = ref.watch(mapTilesEnabledProvider);
    final center = cells.isEmpty
        ? const LatLng(35.8256, 10.6084)
        : LatLng(cells.first.center.lat, cells.first.center.lng);
    return LayeredPage(
      header: HeroHeader(
        title: l.heatmapTitle,
        subtitle: l.heatmapSubtitle,
        emoji: '🗺️',
        gradient: EcoGradients.coral,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.forecastAdmin),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        if (records.isLoading) const Center(child: CircularProgressIndicator()),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 380,
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 12),
              children: [
                if (tiles)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ecoflow',
                  ),
                CircleLayer(
                  circles: [
                    for (final z in zones)
                      CircleMarker(
                        point: LatLng(z.center.lat, z.center.lng),
                        radius: z.radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: EcoColors.primary.withValues(alpha: .04),
                        borderColor: EcoColors.primary.withValues(alpha: .5),
                        borderStrokeWidth: 1.5,
                      ),
                    for (final c in cells)
                      CircleMarker(
                        point: LatLng(c.center.lat, c.center.lng),
                        radius: 250 + 450 * sqrt(c.kg / max(maxKg, 1)),
                        useRadiusInMeter: true,
                        color: heatColor(c.kg / max(maxKg, 1)).withValues(alpha: .6),
                        borderColor: Colors.white,
                        borderStrokeWidth: 1,
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [TextSourceAttribution('© OpenStreetMap')],
                ),
              ],
            ),
          ),
        ),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.heatmapLegend, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(colors: [heatColor(0), heatColor(.5), heatColor(1)]),
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [Text(l.kg('0')), const Spacer(), Text(l.kg(fmtKg(context, maxKg)))]),
            ],
          ),
        ),
        SectionTitle('🔥 ${l.heatmapTop}'),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              if (cells.isEmpty)
                Padding(padding: const EdgeInsets.all(8), child: Text(l.dashEmpty)),
              for (final (i, z)
                  in (zones.toList()..sort(
                        (a, b) => (forecasts[b.id]?.next(30) ?? 0).compareTo(
                          forecasts[a.id]?.next(30) ?? 0,
                        ),
                      ))
                      .indexed)
                if (forecasts[z.id] case final f?)
                  EcoListTile(
                    leading: EcoAvatar(text: '${i + 1}'),
                    title: z.name,
                    subtitle: l.heatmapZoneForecast(l.kg(fmtKg(context, f.next(30)))),
                    showDivider: i < zones.length - 1,
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
