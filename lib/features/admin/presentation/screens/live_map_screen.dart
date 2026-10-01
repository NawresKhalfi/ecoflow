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
import '../../../collection/domain/collection_request.dart';
import '../../../collection/presentation/widgets/collection_labels.dart';
import '../../../collection/presentation/widgets/location_picker.dart';
import '../../application/admin_providers.dart';
import '../../domain/platform_stats.dart';

/// Groupe de statut affiché sur la carte : couleur fixe par groupe.
enum _Group { waiting, assigned, onSite }

_Group _group(String s) => switch (s) {
  'searching' || 'noCollector' || 'proposed' => _Group.waiting,
  'accepted' => _Group.assigned,
  _ => _Group.onSite,
};

Color _color(_Group g) => switch (g) {
  _Group.waiting => EcoColors.sunDeep,
  _Group.assigned => EcoColors.skyDeep,
  _Group.onSite => EcoColors.primary,
};

/// Carte de supervision : collectes en cours et planifiées, collecteurs en
/// ligne (US-108).
class LiveMapScreen extends ConsumerWidget {
  const LiveMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final live = ref.watch(liveCollectionsProvider).value ?? const <CollectionStat>[];
    final online = ref.watch(onlineCollectorsProvider).value ?? const [];
    final zones = ref.watch(collectionConfigProvider).value?.zones ?? const [];
    final tiles = ref.watch(mapTilesEnabledProvider);
    final located = live.where((c) => c.point != null).toList();
    final counts = {
      for (final g in _Group.values) g: live.where((c) => _group(c.status) == g).length,
    };
    String groupLabel(_Group g) => switch (g) {
      _Group.waiting => l.liveWaiting,
      _Group.assigned => l.liveAssigned,
      _Group.onSite => l.liveOnSite,
    };
    return LayeredPage(
      header: HeroHeader(
        title: l.liveMapTitle,
        subtitle: l.liveMapSubtitle,
        emoji: '🗺️',
        gradient: EcoGradients.sky,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.supervision),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final g in _Group.values)
              Semantics(
                label: '${groupLabel(g)} : ${counts[g]}',
                child: Chip(
                  avatar: CircleAvatar(backgroundColor: _color(g), radius: 6),
                  label: Text('${groupLabel(g)} · ${counts[g]}'),
                ),
              ),
            Chip(avatar: const Text('🚚'), label: Text(l.liveCollectors(online.length))),
          ],
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 420,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: located.isEmpty
                    ? const LatLng(35.8256, 10.6084)
                    : LatLng(located.first.point!.lat, located.first.point!.lng),
                initialZoom: 11,
              ),
              children: [
                if (tiles)
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ecoflow',
                  ),
                CircleLayer(
                  circles: [
                    for (final z in zones.where((z) => z.active))
                      CircleMarker(
                        point: LatLng(z.center.lat, z.center.lng),
                        radius: z.radiusKm * 1000,
                        useRadiusInMeter: true,
                        color: EcoColors.primary.withValues(alpha: .04),
                        borderColor: EcoColors.primary.withValues(alpha: .4),
                        borderStrokeWidth: 1.5,
                      ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    for (final c in located)
                      Marker(
                        point: LatLng(c.point!.lat, c.point!.lng),
                        width: 22,
                        height: 22,
                        child: Semantics(
                          label: statusLabel(
                            l,
                            CollectionStatus.values.firstWhere(
                              (s) => s.name == c.status,
                              orElse: () => CollectionStatus.searching,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _color(_group(c.status)),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    for (final o in online)
                      Marker(
                        point: LatLng(o.point.lat, o.point.lng),
                        width: 30,
                        height: 30,
                        child: const Text('🚚', style: TextStyle(fontSize: 22)),
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
        EcoCard(child: Text('ℹ️ ${l.liveMapHelp}')),
      ],
    );
  }
}
