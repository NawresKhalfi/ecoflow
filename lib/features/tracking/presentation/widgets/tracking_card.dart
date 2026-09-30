import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/domain/collection_request.dart';
import '../../../collection/presentation/widgets/location_picker.dart';
import '../../../missions/application/collector_controllers.dart';
import '../../application/tracking_providers.dart';
import '../../domain/eta.dart';

/// Suivi en direct du collecteur et heure d'arrivée (US-063, US-064),
/// visible uniquement quand il est en route ou arrivé.
class TrackingCard extends ConsumerWidget {
  const TrackingCard({super.key, required this.request});
  final CollectionRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final live = ref.watch(livePositionProvider(request.id)).value;
    final now = ref.watch(tickerProvider).value ?? ref.read(clockProvider)();
    final arrived = request.status == CollectionStatus.arrived;
    final dest = request.place.point;
    final tiles = ref.watch(mapTilesEnabledProvider);
    final hm = DateFormat.Hm(Localizations.localeOf(context).languageCode);
    final eta = live == null ? null : estimateArrival(from: live, to: dest, now: now);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🚚 ${l.trackTitle}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 220,
              child: !tiles
                  ? const ColoredBox(color: Color(0xFFDDEBDD), child: SizedBox.expand())
                  : FlutterMap(
                      key: ValueKey(live?.at),
                      options: MapOptions(
                        initialCameraFit: live == null
                            ? null
                            : CameraFit.coordinates(
                                coordinates: [
                                  LatLng(dest.lat, dest.lng),
                                  LatLng(live.point.lat, live.point.lng),
                                ],
                                padding: const EdgeInsets.all(40),
                                maxZoom: 16,
                              ),
                        initialCenter: LatLng(dest.lat, dest.lng),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.ecoflow',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(dest.lat, dest.lng),
                              child: const Icon(
                                Icons.home_rounded,
                                color: EcoColors.primary,
                                size: 32,
                              ),
                            ),
                            if (live != null)
                              Marker(
                                point: LatLng(live.point.lat, live.point.lng),
                                width: 44,
                                height: 44,
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: EcoColors.coral,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                  ),
                                  child: const Text('🚚', style: TextStyle(fontSize: 20)),
                                ),
                              ),
                          ],
                        ),
                        const Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: ColoredBox(
                              color: Color(0xCCFFFFFF),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Text(
                                  '© OpenStreetMap',
                                  style: TextStyle(fontSize: 10, color: Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (arrived)
            EcoChip(label: '📍 ${l.trackHere}')
          else if (live == null)
            Text(l.trackWaiting, style: Theme.of(context).textTheme.bodySmall)
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(l.trackEtaTitle, style: Theme.of(context).textTheme.titleSmall),
                ),
                Text(
                  l.trackEta(hm.format(eta!), eta.difference(now).inMinutes.clamp(0, 999)),
                  style: AppTheme.weighted(18, 800, color: EcoColors.primary),
                ),
              ],
            ),
            Text(
              isStale(live, now)
                  ? '⚠️ ${l.trackStale}'
                  : l.trackUpdated(now.difference(live.at).inSeconds.clamp(0, 999)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(l.trackTraffic, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
