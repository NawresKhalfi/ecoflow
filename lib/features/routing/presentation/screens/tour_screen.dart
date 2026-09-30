import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/presentation/widgets/collection_labels.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../missions/application/mission_actions_controller.dart';
import '../../../missions/presentation/widgets/mission_labels.dart';
import '../../application/routing_providers.dart';
import '../../domain/tour.dart';
import '../widgets/savings_card.dart';
import '../widgets/tour_map.dart';

/// Tournée optimisée du collecteur (US-057 à US-061).
class TourScreen extends ConsumerWidget {
  const TourScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final plan = ref.watch(tourPlanProvider);
    final detours = ref.watch(detourSuggestionsProvider);
    final actions = ref.read(missionActionsControllerProvider.notifier);
    ref.watch(missionActionsControllerProvider);
    final hm = DateFormat.Hm(Localizations.localeOf(context).languageCode);
    var n = 0;
    return LayeredPage(
      header: HeroHeader(
        title: l.tourTitle,
        subtitle: plan == null
            ? l.tourSubtitle
            : '${dayLabel(context, plan.day)} · ${l.tourSummary(plan.tour.order.length, fmtKm(context, plan.tour.distanceKm), plan.tour.activeMinutes.round())}',
        emoji: '🗺️',
        gradient: EcoGradients.sky,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.missions),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        if (plan == null) ...[
          if (ref.watch(lastTourSavingsProvider) case (final day, final count, final savings))
            SavingsCard(
              savings: savings,
              title: '${l.tourDoneTitle} · ${dayLabel(context, day)} · $count',
            )
          else
            EcoCard(child: Text(l.tourEmpty)),
        ] else ...[
          TourMap(start: plan.start, tour: plan.tour),
          SavingsCard(savings: plan.savings),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                EcoListTile(
                  leading: const EcoAvatar(text: '📍'),
                  title: l.tourStart,
                  subtitle: hm.format(plan.startAt),
                ),
                for (final (i, v) in plan.tour.visits.indexed)
                  v.kind == VisitKind.unload
                      ? EcoListTile(
                          leading: const EcoAvatar(text: '🏭', gradient: EcoGradients.violet),
                          title: l.tourUnload,
                          subtitle: l.tourEta(hm.format(v.arrival)),
                          showDivider: i < plan.tour.visits.length - 1,
                        )
                      : EcoListTile(
                          leading: EcoAvatar(text: '${++n}', gradient: EcoGradients.coral),
                          title: v.stop!.label,
                          subtitle: [
                            l.tourEta(hm.format(v.arrival)),
                            if (v.waitMinutes >= 1) l.tourWait(v.waitMinutes.round()),
                            l.kg(fmtKg(context, v.loadAfterKg)),
                          ].join(' · '),
                          showDivider: i < plan.tour.visits.length - 1,
                          trailing: EcoChip(
                            label: statusLabel(l, plan.missions[v.stop!.id]!.status),
                            tone: statusTone(plan.missions[v.stop!.id]!.status),
                          ),
                          onTap: () => context.go(Routes.missionDetail(v.stop!.id)),
                        ),
              ],
            ),
          ),
          for (final s in plan.tour.unassigned)
            EcoCard(child: Text('⚠️ ${s.label} — ${l.tourUnassigned}')),
          Center(
            child: Text(
              l.tourComputed(plan.computeMs),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SectionTitle('🧭 ${l.tourDetourTitle}'),
          if (detours.isEmpty)
            EcoCard(child: Text(l.tourDetourEmpty))
          else
            for (final (m, d) in detours)
              EcoCard(
                child: Row(
                  children: [
                    const EcoAvatar(text: '➕'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.place.address, style: Theme.of(context).textTheme.titleSmall),
                          Text(
                            '${l.tourDetourKm(fmtKm(context, d.extraKm))} · ${l.approxDt(fmtDt(context, m.estimatedDt))}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    EcoChip(label: l.tourAdd, onTap: () => actions.accept(m)),
                  ],
                ),
              ),
        ],
      ],
    );
  }
}
