import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../collection/domain/collection_request.dart';
import '../../../collection/presentation/widgets/collection_labels.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/collector_controllers.dart';
import '../../application/mission_actions_controller.dart';
import '../../data/mission_repository.dart';
import '../../domain/mission_rules.dart';
import 'mission_labels.dart';

/// Carte d'une mission disponible (US-043/044) : matières, poids, distance,
/// valeur, et pour une proposition le compte à rebours de 60 s.
class MissionCard extends ConsumerWidget {
  const MissionCard({super.key, required this.request, this.distanceKm});

  final CollectionRequest request;
  final double? distanceKm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = request;
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final uid = ref.watch(currentUidProvider);
    final proposed = r.status == CollectionStatus.proposed && r.proposedCollectorUid == uid;
    final now = proposed ? (ref.watch(tickerProvider).value ?? ref.read(clockProvider)()) : null;
    final left = proposed ? proposalRemaining(r, now!).inSeconds : 0;
    final actions = ref.read(missionActionsControllerProvider.notifier);
    ref.watch(missionActionsControllerProvider);

    // Délai de 60 s écoulé : refus automatique (la recherche reprend).
    if (proposed && left <= 0 && r.proposedAt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => actions.refuse(r));
    }
    final emojis = r.categories.map((c) => categoryById(catalog, c).emoji).toSet().join(' ');
    final names = r.categories
        .map((c) => categoryById(catalog, c).name(languageOf(context)))
        .toSet()
        .join(', ');
    return EcoCard(
      onTap: () => context.go(Routes.missionDetail(r.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EcoAvatar(text: emojis.isEmpty ? '♻️' : emojis.split(' ').first),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      [
                        if (names.isNotEmpty) names,
                        l.approxKg(fmtKg(context, r.estimatedKg)),
                        if (distanceKm != null) l.missionDistance(fmtKm(context, distanceKm!)),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(slotLabel(context, r.slot), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              EcoChip(label: l.approxDt(fmtDt(context, r.estimatedDt)), tone: ChipTone.sun),
            ],
          ),
          if (proposed) ...[
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                EcoChip(label: '⭐ ${l.missionProposed}', tone: ChipTone.violet),
                Text(
                  l.missionCountdown(left),
                  style: AppTheme.weighted(14, 800, color: const Color(0xFFC4482A)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (proposed) ...[
                Expanded(
                  child: EcoButton(
                    label: l.missionRefuse,
                    style: EcoButtonStyle.ghost,
                    onPressed: () => actions.refuse(r),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: EcoButton(
                  label: l.missionAccept,
                  style: EcoButtonStyle.green,
                  onPressed: () async {
                    final ok = await actions.accept(r);
                    if (!context.mounted) return;
                    final err = ref.read(missionActionsControllerProvider).error;
                    showEcoToast(
                      context,
                      ok
                          ? l.missionAccepted
                          : (err is MissionTaken ? l.missionTaken : l.failUnknown),
                    );
                    if (ok) context.go(Routes.missionDetail(r.id));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
