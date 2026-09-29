import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../domain/geo.dart';
import '../../domain/service_zone.dart';

/// Tuiles réseau désactivables (tests hors ligne).
final mapTilesEnabledProvider = Provider<bool>((ref) => true);

/// Carte OpenStreetMap avec épingle fixe au centre : l'utilisateur déplace
/// la carte pour positionner la collecte (US-031).
class PinMap extends ConsumerStatefulWidget {
  const PinMap({super.key, required this.point, required this.onMoved, this.height = 240});

  final GeoPoint? point;
  final ValueChanged<GeoPoint> onMoved;
  final double height;

  @override
  ConsumerState<PinMap> createState() => _PinMapState();
}

class _PinMapState extends ConsumerState<PinMap> {
  final _map = MapController();
  GeoPoint? _lastExternal;

  @override
  void didUpdateWidget(PinMap old) {
    super.didUpdateWidget(old);
    final p = widget.point;
    // Position choisie ailleurs (GPS, adresse) : recentrer la carte.
    if (p != null && p != _lastExternal && p != old.point) {
      _lastExternal = p;
      try {
        _map.move(LatLng(p.lat, p.lng), 16);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.point ?? defaultZones[1].center;
    final tiles = ref.watch(mapTilesEnabledProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            if (tiles)
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: LatLng(start.lat, start.lng),
                  initialZoom: widget.point == null ? 12 : 16,
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) {
                      widget.onMoved(GeoPoint(camera.center.latitude, camera.center.longitude));
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.ecoflow',
                  ),
                ],
              )
            else
              const ColoredBox(color: Color(0xFFDDEBDD), child: SizedBox.expand()),
            // Attribution OpenStreetMap (obligatoire), discrète en bas à droite.
            if (tiles)
              Positioned(
                right: 8,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .8),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '© OpenStreetMap',
                    style: TextStyle(fontSize: 10, color: Colors.black87),
                  ),
                ),
              ),
            const IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 36),
                  child: Icon(Icons.location_pin, size: 44, color: EcoColors.coral),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastille indiquant si le point est dans une zone desservie.
class ZoneChip extends StatelessWidget {
  const ZoneChip({super.key, required this.zone, required this.hasPoint});
  final ServiceZone? zone;
  final bool hasPoint;

  @override
  Widget build(BuildContext context) {
    if (!hasPoint) return const SizedBox.shrink();
    final l = context.l10n;
    return zone == null
        ? EcoChip(label: '✕ ${l.reqZoneOut}', tone: ChipTone.coral)
        : EcoChip(label: '✓ ${l.reqZoneOk(zone!.name)}');
  }
}
