import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/collection_providers.dart';
import '../../domain/collection_request.dart';
import '../widgets/collection_labels.dart';

enum StatusFilter { all, open, done, cancelled }

/// Filtre pur (US-038) : statut et période.
List<CollectionRequest> filterCollections(
  List<CollectionRequest> list,
  StatusFilter f, {
  required bool last30Days,
  required DateTime now,
}) => [
  for (final r in list)
    if ((switch (f) {
          StatusFilter.all => true,
          StatusFilter.open => r.status.isOpen,
          StatusFilter.done => r.status == CollectionStatus.completed,
          StatusFilter.cancelled => r.status == CollectionStatus.cancelled,
        }) &&
        (!last30Days || r.slot.start.isAfter(now.subtract(const Duration(days: 30)))))
      r,
];

/// Historique des demandes du citoyen (US-038).
class CollectionsScreen extends ConsumerStatefulWidget {
  const CollectionsScreen({super.key});

  @override
  ConsumerState<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends ConsumerState<CollectionsScreen> {
  StatusFilter _filter = StatusFilter.all;
  bool _last30 = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(myCollectionsProvider).value ?? const [];
    final list = filterCollections(
      all,
      _filter,
      last30Days: _last30,
      now: ref.watch(clockProvider)(),
    );
    final labels = {
      StatusFilter.all: l.filterAll,
      StatusFilter.open: l.filterOpen,
      StatusFilter.done: l.filterDone,
      StatusFilter.cancelled: l.filterCancelled,
    };
    return LayeredPage(
      header: HeroHeader(
        title: l.collectionsTitle,
        subtitle: l.collectionsSubtitle,
        emoji: '🚚',
        gradient: EcoGradients.coral,
      ),
      children: [
        EcoCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in labels.entries)
                EcoChip(
                  label: e.value,
                  selected: _filter == e.key,
                  onTap: () => setState(() => _filter = e.key),
                ),
              EcoChip(
                label: _last30 ? l.filterLast30 : l.filterAnyDate,
                tone: ChipTone.sky,
                selected: _last30,
                onTap: () => setState(() => _last30 = !_last30),
              ),
            ],
          ),
        ),
        if (list.isEmpty)
          EcoCard(
            onTap: () => context.go(Routes.scan),
            child: Row(
              children: [
                const EcoAvatar(text: '📸', gradient: EcoGradients.coral),
                const SizedBox(width: 14),
                Expanded(child: Text(l.collectionsEmpty)),
              ],
            ),
          )
        else
          ResponsiveGrid(children: [for (final r in list) _CollectionTile(request: r)]),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.request});
  final CollectionRequest request;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = request;
    return EcoCard(
      onTap: () => context.go(Routes.collectionDetail(r.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  slotLabel(context, r.slot),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              EcoChip(label: statusLabel(l, r.status), tone: statusTone(r.status)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r.place.address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${l.approxKg(fmtKg(context, r.estimatedKg))} · ${l.approxDt(fmtDt(context, r.estimatedDt))}'
            '${r.recurrence == Recurrence.none ? '' : ' · 🔁'}',
          ),
        ],
      ),
    );
  }
}
