import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../missions/application/mission_actions_controller.dart';
import '../../../missions/presentation/widgets/mission_labels.dart';
import '../../application/routing_providers.dart';
import '../../domain/tour_change.dart';

/// Accès à la tournée optimisée depuis les missions (US-057).
class TourEntryCard extends ConsumerWidget {
  const TourEntryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final plan = ref.watch(tourPlanProvider);
    if (plan == null) return const SizedBox.shrink();
    final white = Colors.white.withValues(alpha: .92);
    return EcoCard(
      gradient: EcoGradients.sky,
      decorated: true,
      onTap: () => context.go(Routes.tour),
      semanticLabel: l.tourOpen,
      child: Row(
        children: [
          const ExcludeSemantics(child: Text('🗺️', style: TextStyle(fontSize: 36))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.tourOpen, style: AppTheme.weighted(18, 800, color: Colors.white)),
                Text(
                  [
                    l.tourSummary(
                      plan.tour.order.length,
                      fmtKm(context, plan.tour.distanceKm),
                      plan.tour.activeMinutes.round(),
                    ),
                    if (plan.savings.isPositive) l.tourSavedKm(fmtKm(context, plan.savings.km)),
                  ].join(' · '),
                  style: AppTheme.weighted(14, 500, color: white),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded, color: Colors.white),
        ],
      ),
    );
  }
}

/// Collectes proches regroupables en une tournée (US-056).
class ClusterSuggestions extends ConsumerWidget {
  const ClusterSuggestions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final clusters = ref.watch(missionClustersProvider);
    final actions = ref.read(missionActionsControllerProvider.notifier);
    ref.watch(missionActionsControllerProvider);
    if (clusters.isEmpty) return const SizedBox.shrink();
    final (missions, cluster) = clusters.first;
    return EcoCard(
      gradient: EcoGradients.violet,
      decorated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🧠 ${l.clusterTitle}', style: AppTheme.weighted(17, 800, color: Colors.white)),
          Text(
            '${l.clusterBody(missions.length, l.kg(fmtKg(context, cluster.totalKg)))} · '
            '${l.approxDt(fmtDt(context, missions.fold(0.0, (s, m) => s + m.estimatedDt)))}',
            style: AppTheme.weighted(14, 500, color: Colors.white.withValues(alpha: .92)),
          ),
          const SizedBox(height: 6),
          for (final m in missions)
            Text(
              '• ${m.place.address}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.weighted(13, 500, color: Colors.white),
            ),
          const SizedBox(height: 10),
          EcoButton(
            label: l.clusterAccept,
            leading: '✅',
            style: EcoButtonStyle.ghost,
            onPressed: () async {
              for (final m in missions) {
                await actions.accept(m);
              }
              if (context.mounted) context.go(Routes.tour);
            },
          ),
        ],
      ),
    );
  }
}

/// Recalcul automatique : prévient le collecteur quand sa tournée change
/// (ajout, annulation, nouvel ordre) — US-059.
void listenTourChanges(BuildContext context, WidgetRef ref) {
  ref.listen<TourPlan?>(tourPlanProvider, (prev, next) {
    if (prev == null || next == null) return;
    final change = diffOrder(
      [for (final s in prev.tour.order) s.id],
      [for (final s in next.tour.order) s.id],
    );
    final l = context.l10n;
    final msg = switch (change) {
      TourChange.none => null,
      TourChange.added => l.tourAddedNotice,
      TourChange.removed => l.tourRemovedNotice,
      TourChange.reordered => l.tourReorderedNotice,
    };
    if (msg != null) showEcoToast(context, '🗺️ $msg');
  });
}
