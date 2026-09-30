import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../collection/domain/geo.dart';
import '../../../collection/presentation/widgets/location_picker.dart';
import '../../domain/tour.dart';

/// Tracé de la tournée : départ, arrêts numérotés dans l'ordre, retours de
/// déchargement (US-057).
class TourMap extends ConsumerWidget {
  const TourMap({super.key, required this.start, required this.tour, this.height = 280});

  final GeoPoint start;
  final Tour tour;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = [
      LatLng(start.lat, start.lng),
      for (final v in tour.visits) LatLng(v.point.lat, v.point.lng),
    ];
    final tiles = ref.watch(mapTilesEnabledProvider);
    var n = 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        child: !tiles
            ? const ColoredBox(color: Color(0xFFDDEBDD), child: SizedBox.expand())
            : FlutterMap(
                options: MapOptions(
                  initialCameraFit: points.length > 1
                      ? CameraFit.coordinates(
                          coordinates: points,
                          padding: const EdgeInsets.all(36),
                        )
                      : null,
                  initialCenter: points.first,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ecoflow',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: 4,
                        color: EcoColors.primary,
                        pattern: StrokePattern.dotted(),
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: points.first,
                        child: const Icon(Icons.my_location, color: EcoColors.skyDeep, size: 26),
                      ),
                      for (final v in tour.visits)
                        Marker(
                          point: LatLng(v.point.lat, v.point.lng),
                          width: 32,
                          height: 32,
                          child: v.kind == VisitKind.unload
                              ? const Icon(Icons.factory_rounded, color: EcoColors.violet, size: 28)
                              : Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: EcoColors.coral,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                  ),
                                  child: Text(
                                    '${++n}',
                                    style: AppTheme.weighted(13, 800, color: Colors.white),
                                  ),
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
    );
  }
}
