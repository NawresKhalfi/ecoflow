import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/collector_controllers.dart';
import '../../application/missions_providers.dart';
import '../../domain/work_zone.dart';

/// Zone de travail en rayon autour du collecteur (US-042).
class WorkZoneCard extends ConsumerWidget {
  const WorkZoneCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final zone = ref.watch(myPresenceDataProvider).value?.zone;
    final state = ref.watch(collectorSettingsControllerProvider);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🎯 ${l.zoneTitle}', style: Theme.of(context).textTheme.titleMedium),
          Text(
            zone == null ? l.zoneNone : l.zoneCurrent(zone.radiusKm.round()),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in workZoneRadiiKm)
                EcoChip(
                  label: l.zoneRadius(r.round()),
                  selected: zone?.radiusKm == r,
                  onTap: state.isLoading
                      ? null
                      : () async {
                          final ok = await ref
                              .read(collectorSettingsControllerProvider.notifier)
                              .saveZone(r);
                          if (context.mounted) {
                            showEcoToast(context, ok ? l.zoneSaved : l.presenceNeedsLocation);
                          }
                        },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l.zoneHelp, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
