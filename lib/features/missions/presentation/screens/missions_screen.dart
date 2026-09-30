import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/application/collection_actions_controller.dart';
import '../../../collection/presentation/widgets/collection_labels.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/missions_providers.dart';
import '../../domain/mission_rules.dart';
import '../../../routing/presentation/widgets/tour_entry_cards.dart';
import '../widgets/mission_card.dart';
import '../widgets/missions_map.dart';

/// Missions disponibles autour du collecteur et ses missions (US-043).
class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  bool _mine = false;
  bool _map = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final online = ref.watch(myPresenceProvider).value ?? false;
    final presence = ref.watch(myPresenceDataProvider).value;
    final available = ref.watch(availableMissionsProvider);
    final mine = ref.watch(myMissionsProvider).value ?? const [];
    return LayeredPage(
      header: HeroHeader(
        title: l.missionsTitle,
        subtitle: online ? '🟢 ${l.presenceOn}' : '⚪ ${l.presenceOff}',
        emoji: '🚚',
        gradient: EcoGradients.coral,
        trailing: Switch(
          value: online,
          onChanged: (v) => ref.read(presenceControllerProvider.notifier).setOnline(v),
        ),
      ),
      children: [
        EcoCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EcoChip(
                label: l.missionsAvailable,
                selected: !_mine,
                onTap: () => setState(() => _mine = false),
              ),
              EcoChip(
                label: l.missionsMine,
                selected: _mine,
                onTap: () => setState(() => _mine = true),
              ),
              if (!_mine) ...[
                EcoChip(
                  label: '📋 ${l.missionsList}',
                  tone: ChipTone.sky,
                  selected: !_map,
                  onTap: () => setState(() => _map = false),
                ),
                EcoChip(
                  label: '🗺️ ${l.missionsMap}',
                  tone: ChipTone.sky,
                  selected: _map,
                  onTap: () => setState(() => _map = true),
                ),
              ],
            ],
          ),
        ),
        if (_mine)
          ..._mineList(context, mine)
        else if (!online)
          EcoCard(child: Text(l.missionsOffline))
        else ...[
          const TourEntryCard(),
          const ClusterSuggestions(),
          const _FilterCard(),
          if (_map)
            MissionsMap(missions: [for (final m in available) m.$1], me: presence?.point)
          else if (available.isEmpty)
            EcoCard(child: Text(l.missionsEmpty))
          else
            ResponsiveGrid(
              minItemWidth: 320,
              children: [for (final (r, d) in available) MissionCard(request: r, distanceKm: d)],
            ),
        ],
      ],
    );
  }

  List<Widget> _mineList(BuildContext context, List mine) {
    final l = context.l10n;
    if (mine.isEmpty) return [EcoCard(child: Text(l.missionsMineEmpty))];
    return [
      EcoCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          children: [
            for (final (i, r) in mine.indexed)
              EcoListTile(
                leading: const EcoAvatar(text: '🚚'),
                title: r.place.address,
                subtitle:
                    '${slotLabel(context, r.slot)} · ${l.approxKg(fmtKg(context, r.estimatedKg))}',
                showDivider: i < mine.length - 1,
                trailing: EcoChip(label: statusLabel(l, r.status), tone: statusTone(r.status)),
                onTap: () => context.go(Routes.missionDetail(r.id)),
              ),
          ],
        ),
      ),
    ];
  }
}

class _FilterCard extends ConsumerWidget {
  const _FilterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = ref.watch(missionFilterProvider);
    final set = ref.read(missionFilterProvider.notifier).set;
    final catalog = (ref.watch(catalogProvider).value ?? defaultCatalog).where(
      (c) => c.active && c.material != null,
    );
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EcoChip(
                label: '📍 ${l.sortDistance}',
                selected: f.sort == MissionSort.distance,
                onTap: () => set(f.copyWith(sort: MissionSort.distance)),
              ),
              EcoChip(
                label: '💰 ${l.sortValue}',
                selected: f.sort == MissionSort.value,
                onTap: () => set(f.copyWith(sort: MissionSort.value)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EcoChip(
                label: l.filterAllMaterials,
                tone: ChipTone.violet,
                selected: f.categories.isEmpty,
                onTap: () => set(f.copyWith(categories: {})),
              ),
              for (final c in catalog)
                EcoChip(
                  label: '${c.emoji} ${c.name(languageOf(context))}',
                  tone: ChipTone.violet,
                  selected: f.categories.contains(c.id),
                  onTap: () {
                    final next = {...f.categories};
                    next.contains(c.id) ? next.remove(c.id) : next.add(c.id);
                    set(f.copyWith(categories: next));
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final min in [0.0, 2.0, 5.0, 10.0])
                EcoChip(
                  label: min == 0 ? l.filterAnyQty : '≥ ${l.kg(min.toStringAsFixed(0))}',
                  tone: ChipTone.sky,
                  selected: f.minKg == min,
                  onTap: () => set(f.copyWith(minKg: min)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
