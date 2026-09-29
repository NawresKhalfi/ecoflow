import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../../estimation/application/estimation_providers.dart';
import '../../../estimation/domain/handover_code.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/collection_actions_controller.dart';
import '../../application/collection_providers.dart';
import '../../domain/collection_request.dart';
import '../../domain/time_slot.dart';
import '../widgets/alternatives_card.dart';
import '../widgets/collection_labels.dart';
import '../widgets/feedback_widgets.dart';
import '../widgets/slot_picker.dart';
import '../widgets/status_timeline.dart';

/// Détail et suivi d'une demande (US-035 à US-041).
class CollectionDetailScreen extends ConsumerWidget {
  const CollectionDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = ref.watch(collectionByIdProvider(id)).value;
    final actions = ref.watch(collectionActionsControllerProvider);
    final ctrl = ref.read(collectionActionsControllerProvider.notifier);
    final now = ref.watch(clockProvider)();
    final error = actions.error;
    // Après la pesée : poids et montant réels (epic 3) au lieu de l'estimation.
    final weighing = r == null
        ? null
        : ref.watch(estimateByCodeProvider(r.estimateCode)).value?.weighing;
    return LayeredPage(
      header: HeroHeader(
        title: r == null ? l.collectionsTitle : statusLabel(l, r.status),
        subtitle: r == null ? null : slotLabel(context, r.slot),
        emoji: '🚚',
        gradient: r?.status == CollectionStatus.completed ? EcoGradients.green : EcoGradients.coral,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.collections),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        if (r == null)
          const Center(child: CircularProgressIndicator())
        else ...[
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Le titre du hero affiche déjà le statut : ici la pastille seule.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: EcoChip(label: statusLabel(l, r.status), tone: statusTone(r.status)),
                ),
                const SizedBox(height: 10),
                if (r.status != CollectionStatus.cancelled) StatusTimeline(status: r.status),
                if (r.status == CollectionStatus.proposed && r.searchRadiusKm != null) ...[
                  const SizedBox(height: 8),
                  EcoChip(
                    label: '🚚 ${l.detMatched(r.searchRadiusKm!.round())}',
                    tone: ChipTone.sky,
                  ),
                ],
                const SizedBox(height: 10),
                EcoListTile(
                  leading: const EcoAvatar(text: '📍'),
                  title: r.place.address,
                  subtitle: slotLabel(context, r.slot),
                ),
                EcoListTile(
                  leading: const EcoAvatar(text: '⚖️'),
                  title: weighing == null
                      ? '${l.approxKg(fmtKg(context, r.estimatedKg))} · ${l.approxDt(fmtDt(context, r.estimatedDt))}'
                      : '${l.detWeighed} : ${l.kg(fmtKg(context, weighing.actualKg))} · ${l.dt(fmtDt(context, weighing.finalDt))}',
                  subtitle: r.instructions.isEmpty ? null : '📝 ${r.instructions}',
                  showDivider: r.recurrence != Recurrence.none,
                ),
                if (r.recurrence != Recurrence.none)
                  EcoListTile(
                    leading: const EcoAvatar(text: '🔁'),
                    title: l.detRecurring(recurrenceLabel(l, r.recurrence)),
                    showDivider: false,
                    trailing: EcoLink(
                      label: l.detStopSeries,
                      onPressed: () => ctrl.stopRecurrence(r),
                    ),
                  ),
              ],
            ),
          ),
          if (error != null)
            ErrorBanner(error is TooLateToModify ? l.reqErrTooLate : failureText(context, error)),
          if (r.status == CollectionStatus.noCollector) AlternativesCard(request: r),
          if (r.status.isOpen && r.status.step < 3) _HandoverCard(code: r.estimateCode),
          if (r.awaitingCitizenConfirmation)
            EcoCard(
              gradient: EcoGradients.violet,
              decorated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.detConfirmHandoverBody,
                    style: AppTheme.weighted(15, 600, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  EcoButton(
                    label: l.detConfirmHandover,
                    leading: '🤝',
                    style: EcoButtonStyle.ghost,
                    loading: actions.isLoading,
                    onPressed: () => ctrl.confirmHandover(r),
                  ),
                ],
              ),
            ),
          if (r.canRate && r.collectorUid != null) RatingCard(request: r),
          if (r.canModify(now))
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                EcoButton(
                  label: l.detModifySlot,
                  leading: '🕒',
                  style: EcoButtonStyle.ghost,
                  expand: false,
                  onPressed: () => _changeSlot(context, ref, r),
                ),
                EcoButton(
                  label: l.detModifyInstructions,
                  leading: '📝',
                  style: EcoButtonStyle.ghost,
                  expand: false,
                  onPressed: () => _editInstructions(context, ref, r),
                ),
              ],
            ),
          if (r.canCancel)
            EcoButton(
              label: l.detCancel,
              leading: '✕',
              style: EcoButtonStyle.ghost,
              onPressed: () => _cancel(context, ref, r),
            ),
          if (r.status.step >= 1 || r.status == CollectionStatus.completed)
            EcoLink(
              label: '⚠️ ${l.detReport}',
              color: const Color(0xFFC4482A),
              onPressed: () => showReportSheet(context, r),
            ),
        ],
      ],
    );
  }

  Future<void> _changeSlot(BuildContext context, WidgetRef ref, CollectionRequest r) async {
    final l = context.l10n;
    final chosen = await showModalBottomSheet<TimeSlot>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final counts = ref.watch(slotCountsProvider(r.place.zoneId)).value ?? const {};
          final capacity = ref.watch(collectionConfigProvider).value?.slotCapacity ?? 10;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.detModifySlot, style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SlotPicker(
                    slots: upcomingSlots(ref.read(clockProvider)()),
                    counts: counts,
                    capacity: capacity,
                    selected: r.slot,
                    onSelect: (s) => Navigator.pop(ctx, s),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (chosen == null || chosen == r.slot) return;
    final ok = await ref.read(collectionActionsControllerProvider.notifier).modify(r, slot: chosen);
    if (ok && context.mounted) showEcoToast(context, l.detModifiedNotice);
  }

  Future<void> _editInstructions(BuildContext context, WidgetRef ref, CollectionRequest r) async {
    final l = context.l10n;
    final controller = TextEditingController(text: r.instructions);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.detModifyInstructions),
        content: TextField(
          controller: controller,
          maxLength: maxInstructionsLength,
          maxLines: 3,
          decoration: InputDecoration(hintText: l.reqInstructionsHint),
        ),
        actions: [
          EcoLink(label: l.commonCancel, onPressed: () => Navigator.pop(ctx, false)),
          EcoLink(label: l.commonSave, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok == true) {
      final saved = await ref
          .read(collectionActionsControllerProvider.notifier)
          .modify(r, instructions: controller.text);
      if (saved && context.mounted) showEcoToast(context, l.detModifiedNotice);
    }
    controller.dispose();
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, CollectionRequest r) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.detCancelConfirm),
        content: Text(r.cancellationPenalty ? l.detCancelPenalty : l.detCancelNoPenalty),
        actions: [
          EcoLink(label: l.commonBack, onPressed: () => Navigator.pop(ctx, false)),
          EcoLink(
            label: l.detCancel,
            color: const Color(0xFFC4482A),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(collectionActionsControllerProvider.notifier).cancel(r, stopSeries: true);
    }
  }
}

/// QR et code de remise à usage unique (US-039).
class _HandoverCard extends StatelessWidget {
  const _HandoverCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EcoCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: QrImageView(data: code, size: 110, semanticsLabel: formatHandoverCode(code)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🔑 ${l.detHandoverTitle}', style: Theme.of(context).textTheme.titleSmall),
                SelectableText(
                  formatHandoverCode(code),
                  style: AppTheme.weighted(24, 800, color: EcoColors.violetDeep, letterSpacing: 3),
                ),
                Text(l.detHandoverHelp, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
