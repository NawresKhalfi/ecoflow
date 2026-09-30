import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../collection/application/collection_providers.dart';
import '../../../collection/domain/collection_request.dart';
import '../../../collection/presentation/widgets/collection_labels.dart';
import '../../../collection/presentation/widgets/status_timeline.dart';
import '../../../estimation/application/estimation_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/mission_actions_controller.dart';
import '../../domain/mission_rules.dart';
import '../widgets/close_mission_card.dart';
import '../widgets/mission_card.dart';
import '../widgets/mission_sections.dart';
import '../widgets/no_show_sheet.dart';

/// Détail et déroulé d'une mission côté collecteur (US-045 à US-053).
class MissionDetailScreen extends ConsumerWidget {
  const MissionDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = ref.watch(collectionByIdProvider(id)).value;
    final uid = ref.watch(currentUidProvider);
    final state = ref.watch(missionActionsControllerProvider);
    final ctrl = ref.read(missionActionsControllerProvider.notifier);
    final mine = r != null && r.collectorUid == uid;
    final weighing = r == null
        ? null
        : ref.watch(estimateByCodeProvider(r.estimateCode)).value?.weighing;
    final stepLabel = switch (r?.status) {
      CollectionStatus.accepted => l.missionStartRoute,
      CollectionStatus.onTheWay => l.missionArrive,
      CollectionStatus.arrived => l.missionStart,
      _ => null,
    };
    return LayeredPage(
      header: HeroHeader(
        title: r == null ? l.navMissions : statusLabel(l, r.status),
        subtitle: r == null ? null : '${slotLabel(context, r.slot)} · ${r.place.address}',
        emoji: '🚚',
        gradient: r?.status == CollectionStatus.completed ? EcoGradients.green : EcoGradients.coral,
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
        if (r == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          if (!mine && canAccept(r, uid ?? '', ref.watch(clockProvider)()))
            MissionCard(request: r)
          else if (mine)
            EcoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (r.status != CollectionStatus.cancelled) StatusTimeline(status: r.status),
                  if (r.status == CollectionStatus.handedOver) ...[
                    const SizedBox(height: 10),
                    Text('⏳ ${l.missionWaitingCitizen}'),
                  ],
                  if (r.status == CollectionStatus.completed && weighing != null) ...[
                    const SizedBox(height: 10),
                    Text(l.missionDone, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      l.missionCredited(l.dt(fmtDt(context, weighing.finalDt))),
                      style: AppTheme.weighted(22, 800, color: EcoColors.primary),
                    ),
                  ],
                  if (stepLabel != null) ...[
                    const SizedBox(height: 12),
                    EcoButton(
                      label: stepLabel,
                      style: EcoButtonStyle.green,
                      loading: state.isLoading,
                      onPressed: () => ctrl.advance(r),
                    ),
                  ],
                ],
              ),
            ),
          if (mine && r.status.isOpen)
            EcoButton(
              label: l.chatOpen,
              leading: '💬',
              style: EcoButtonStyle.ghost,
              onPressed: () => context.go(Routes.chat(r.id)),
            ),
          WasteSection(request: r),
          if (mine && r.status.isOpen && r.status.step < 3) NavigationSection(request: r),
          if (mine && r.status == CollectionStatus.inProgress) ...[
            ProofSection(request: r),
            CloseMissionCard(request: r),
          ],
          if (mine && canReportNoShow(r))
            EcoLink(
              label: '⚠️ ${l.missionNoShow}',
              color: const Color(0xFFC4482A),
              onPressed: () => showNoShowSheet(context, r),
            ),
        ],
      ],
    );
  }
}
