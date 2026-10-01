import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/application/collection_providers.dart';
import '../../../collection/domain/feedback.dart';
import '../../../collection/presentation/widgets/collection_labels.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/admin_providers.dart';
import '../../domain/admin.dart';

/// Litiges et signalements des collectes (US-112) ; les signalements de la
/// marketplace se traitent dans la modération.
class DisputesScreen extends ConsumerStatefulWidget {
  const DisputesScreen({super.key});

  @override
  ConsumerState<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends ConsumerState<DisputesScreen> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final all = ref.watch(disputesProvider).value ?? const <Dispute>[];
    final shown = all.where((d) => (d.status == DisputeStatus.open) == _open).toList();
    return LayeredPage(
      header: HeroHeader(
        title: l.disputesTitle,
        subtitle: l.disputesSubtitle,
        emoji: '⚖️',
        gradient: EcoGradients.coral,
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
        Wrap(
          spacing: 8,
          children: [
            EcoChip(
              label: l.disputesOpen,
              selected: _open,
              onTap: () => setState(() => _open = true),
            ),
            EcoChip(
              label: l.disputesClosed,
              selected: !_open,
              onTap: () => setState(() => _open = false),
            ),
          ],
        ),
        if (shown.isEmpty) EcoCard(child: Text('✅ ${l.disputesNone}')),
        for (final d in shown) _DisputeCard(dispute: d, key: ValueKey(d.id)),
        EcoLink(label: '🧹 ${l.modTitle}', onPressed: () => context.go(Routes.moderation)),
      ],
    );
  }
}

class _DisputeCard extends ConsumerStatefulWidget {
  const _DisputeCard({super.key, required this.dispute});
  final Dispute dispute;

  @override
  ConsumerState<_DisputeCard> createState() => _DisputeCardState();
}

class _DisputeCardState extends ConsumerState<_DisputeCard> {
  final _decision = TextEditingController();
  List<Uint8List>? _photos;

  @override
  void dispose() {
    _decision.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = widget.dispute;
    final now = ref.watch(clockProvider)();
    final state = ref.watch(adminControllerProvider);
    final ctrl = ref.read(adminControllerProvider.notifier);
    final reason = ProblemReason.values.where((r) => r.name == d.reason).firstOrNull;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '⚠️ ${reason == null ? d.reason : reasonLabel(l, reason)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            [
              d.reporterRole == 'collector' ? l.disputeByCollector : l.disputeByCitizen,
              if (d.createdAt != null) fmtDate(context, d.createdAt!),
              if (d.status == DisputeStatus.open) l.disputeAge(d.age(now).inDays),
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (d.description.isNotEmpty) ...[const SizedBox(height: 6), Text(d.description)],
          // Résumé de la collecte concernée (lecture admin).
          if (ref.watch(collectionByIdProvider(d.collectionId)).value case final c?)
            EcoListTile(
              leading: const EcoAvatar(text: '🚚'),
              title: c.place.address,
              subtitle: '${statusLabel(l, c.status)} · ${slotLabel(context, c.slot)}',
              showDivider: false,
            ),
          if (d.photoCount > 0)
            _photos == null
                ? TextButton(
                    onPressed: () async {
                      final p = await ref.read(adminRepositoryProvider).disputePhotos(d.id);
                      if (mounted) setState(() => _photos = p);
                    },
                    child: Text(l.disputePhotos(d.photoCount)),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in _photos!)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(p, width: 96, height: 96, fit: BoxFit.cover),
                        ),
                    ],
                  ),
          if (d.status == DisputeStatus.open) ...[
            const SizedBox(height: 8),
            EcoTextField(label: l.disputeDecision, controller: _decision, maxLength: 500),
            Row(
              children: [
                Expanded(
                  child: EcoButton(
                    label: l.disputeReject,
                    style: EcoButtonStyle.ghost,
                    loading: state.isLoading,
                    onPressed: () => _resolve(context, ctrl, upheld: false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: EcoButton(
                    label: l.disputeUphold,
                    style: EcoButtonStyle.green,
                    loading: state.isLoading,
                    onPressed: () => _resolve(context, ctrl, upheld: true),
                  ),
                ),
              ],
            ),
          ] else
            EcoChip(
              label: '${d.status == DisputeStatus.resolved ? '✅' : '✖️'} ${d.resolution}',
              tone: d.status == DisputeStatus.resolved ? ChipTone.green : ChipTone.sun,
            ),
        ],
      ),
    );
  }

  Future<void> _resolve(BuildContext context, AdminController ctrl, {required bool upheld}) async {
    final ok = await ctrl.resolve(widget.dispute, upheld: upheld, resolution: _decision.text);
    if (!context.mounted) return;
    showEcoToast(context, ok ? context.l10n.disputeDone : context.l10n.disputeDecisionRequired);
  }
}
