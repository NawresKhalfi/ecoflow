import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../collection/domain/collection_request.dart';
import '../../../collection/domain/geo.dart';
import '../../../collection/domain/service_zone.dart';
import '../../../collection/presentation/widgets/location_picker.dart';

/// Carte des missions (US-043) ou d'une destination (US-046).
class MissionsMap extends ConsumerWidget {
  const MissionsMap({super.key, required this.missions, this.me, this.height = 320});

  final List<CollectionRequest> missions;
  final GeoPoint? me;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = me ?? (missions.isEmpty ? defaultZones[1].center : missions.first.place.point);
    final tiles = ref.watch(mapTilesEnabledProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        child: tiles
            ? FlutterMap(
                options: MapOptions(initialCenter: LatLng(center.lat, center.lng), initialZoom: 13),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ecoflow',
                  ),
                  MarkerLayer(
                    markers: [
                      if (me != null)
                        Marker(
                          point: LatLng(me!.lat, me!.lng),
                          child: const Icon(Icons.my_location, color: EcoColors.skyDeep, size: 28),
                        ),
                      for (final m in missions)
                        Marker(
                          point: LatLng(m.place.point.lat, m.place.point.lng),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => context.go(Routes.missionDetail(m.id)),
                            child: const Icon(Icons.location_pin, color: EcoColors.coral, size: 40),
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
              )
            : const ColoredBox(color: Color(0xFFDDEBDD), child: SizedBox.expand()),
      ),
    );
  }
}
