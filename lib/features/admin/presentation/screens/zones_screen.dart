import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/application/collection_providers.dart';
import '../../../collection/domain/geo.dart';
import '../../../collection/domain/service_zone.dart';
import '../../../collection/presentation/widgets/location_picker.dart';
import '../../application/admin_providers.dart';

/// Zones desservies (US-117) : les demandes hors zone active sont refusées
/// au formulaire de collecte.
class ZonesScreen extends ConsumerStatefulWidget {
  const ZonesScreen({super.key});

  @override
  ConsumerState<ZonesScreen> createState() => _ZonesScreenState();
}

class _ZonesScreenState extends ConsumerState<ZonesScreen> {
  List<ServiceZone>? _draft;

  String _slug(String name) => name
      .toLowerCase()
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[àâ]'), 'a')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final saved = ref.watch(collectionConfigProvider).value?.zones;
    final zones = _draft ?? saved ?? const <ServiceZone>[];
    final state = ref.watch(adminControllerProvider);
    final tiles = ref.watch(mapTilesEnabledProvider);
    return LayeredPage(
      header: HeroHeader(
        title: l.zonesTitle,
        subtitle: l.zonesSubtitle,
        emoji: '📍',
        gradient: EcoGradients.green,
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
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              options: const MapOptions(initialCenter: LatLng(35.6, 10.4), initialZoom: 7),
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
                        color: (z.active ? EcoColors.primary : Colors.grey).withValues(alpha: .18),
                        borderColor: z.active ? EcoColors.primary : Colors.grey,
                        borderStrokeWidth: 2,
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
        if (_draft != null) EcoChip(label: l.optDraft, tone: ChipTone.sun),
        for (final (i, z) in zones.indexed)
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: z.active,
                  title: Text(z.name, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                    '${z.center.lat.toStringAsFixed(4)}, ${z.center.lng.toStringAsFixed(4)}',
                  ),
                  onChanged: (v) => setState(
                    () => _draft = [...zones]
                      ..[i] = ServiceZone(
                        id: z.id,
                        name: z.name,
                        center: z.center,
                        radiusKm: z.radiusKm,
                        active: v,
                      ),
                  ),
                ),
                Text(l.zonesRadius(z.radiusKm.round())),
                Slider(
                  value: z.radiusKm.clamp(2, 50),
                  min: 2,
                  max: 50,
                  divisions: 48,
                  label: '${z.radiusKm.round()} km',
                  onChanged: (v) => setState(
                    () => _draft = [...zones]
                      ..[i] = ServiceZone(
                        id: z.id,
                        name: z.name,
                        center: z.center,
                        radiusKm: v.roundToDouble(),
                        active: z.active,
                      ),
                  ),
                ),
                EcoLink(
                  label: l.zonesDelete,
                  color: const Color(0xFFC4482A),
                  onPressed: () => setState(() => _draft = [...zones]..removeAt(i)),
                ),
              ],
            ),
          ),
        EcoButton(
          label: l.zonesAdd,
          leading: '＋',
          style: EcoButtonStyle.ghost,
          onPressed: () async {
            final z = await _newZone(context);
            if (z != null) setState(() => _draft = [...zones, z]);
          },
        ),
        EcoButton(
          label: l.optPublish,
          leading: '📢',
          style: EcoButtonStyle.green,
          loading: state.isLoading,
          onPressed: _draft == null
              ? null
              : () async {
                  if (await ref.read(adminControllerProvider.notifier).saveZones(_draft!) &&
                      context.mounted) {
                    setState(() => _draft = null);
                    showEcoToast(context, l.optPublished);
                  }
                },
        ),
      ],
    );
  }

  Future<ServiceZone?> _newZone(BuildContext context) async {
    final l = context.l10n;
    final name = TextEditingController();
    final lat = TextEditingController();
    final lng = TextEditingController();
    double? n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + MediaQuery.viewInsetsOf(c).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.zonesAdd, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 10),
            EcoTextField(label: l.zonesName, controller: name),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: EcoTextField(
                    label: 'Latitude',
                    controller: lat,
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EcoTextField(
                    label: 'Longitude',
                    controller: lng,
                    keyboardType: TextInputType.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            EcoButton(
              label: l.commonSave,
              style: EcoButtonStyle.green,
              onPressed: () => Navigator.pop(c, true),
            ),
          ],
        ),
      ),
    );
    final zone = ok == true && name.text.trim().isNotEmpty && n(lat) != null && n(lng) != null
        ? ServiceZone(
            id: _slug(name.text),
            name: name.text.trim(),
            center: GeoPoint(n(lat)!, n(lng)!),
            radiusKm: 10,
          )
        : null;
    disposeAfterSheet([name, lat, lng]);
    return zone;
  }
}
