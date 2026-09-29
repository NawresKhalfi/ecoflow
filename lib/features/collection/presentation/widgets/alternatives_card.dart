import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/collection_actions_controller.dart';
import '../../application/collection_providers.dart';
import '../../domain/collection_request.dart';
import '../../domain/service_zone.dart';
import '../../domain/time_slot.dart';
import 'collection_labels.dart';

/// Aucun collecteur : autres créneaux, points de dépôt, file d'attente (US-036).
class AlternativesCard extends ConsumerWidget {
  const AlternativesCard({super.key, required this.request});
  final CollectionRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ctrl = ref.read(collectionActionsControllerProvider.notifier);
    final config = ref.watch(collectionConfigProvider).value;
    final counts = ref.watch(slotCountsProvider(request.place.zoneId)).value ?? const {};
    final free = freeSlotsAfter(
      upcomingSlots(ref.watch(clockProvider)()),
      counts,
      config?.slotCapacity ?? 10,
      request.slot,
    );
    final zoneName =
        (config?.zones ?? defaultZones)
            .where((z) => z.id == request.place.zoneId)
            .firstOrNull
            ?.name ??
        '';
    final drops = ref.watch(dropPointsProvider(zoneName)).value ?? const [];
    return EcoCard(
      gradient: EcoGradients.sun,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🤔 ${l.detAlternativesTitle}',
            style: AppTheme.weighted(17, 800, color: EcoColors.onSun),
          ),
          if (request.searchRadiusKm != null)
            Text(
              l.detSearchedUpTo(request.searchRadiusKm!.round()),
              style: const TextStyle(color: EcoColors.onSun),
            ),
          if (free.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l.detAlternativesSlots, style: AppTheme.weighted(14, 700, color: EcoColors.onSun)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in free)
                  EcoChip(
                    label: slotLabel(context, s),
                    tone: ChipTone.sky,
                    onTap: () => ctrl.modify(request, slot: s),
                  ),
              ],
            ),
          ],
          if (drops.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(l.detAlternativesDrop, style: AppTheme.weighted(14, 700, color: EcoColors.onSun)),
            for (final d in drops)
              Text('🏭 ${d.name} · ${d.city}', style: const TextStyle(color: EcoColors.onSun)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EcoButton(
                label: l.detQueue,
                leading: '⏳',
                style: EcoButtonStyle.ghost,
                expand: false,
                onPressed: () => ctrl.retryMatching(request),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
