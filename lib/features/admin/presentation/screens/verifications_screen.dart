import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../application/admin_providers.dart';
import '../../data/admin_repository.dart';

/// Validation des dossiers collecteurs et recycleurs (US-107).
class VerificationsScreen extends ConsumerWidget {
  const VerificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final pending = ref.watch(pendingReviewsProvider);
    return LayeredPage(
      header: HeroHeader(
        title: l.verifTitle,
        subtitle: l.verifSubtitle,
        emoji: '🪪',
        gradient: EcoGradients.sky,
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
        if (pending.isLoading) const Center(child: CircularProgressIndicator()),
        if (pending.value?.isEmpty ?? false) EcoCard(child: Text('✅ ${l.verifNone}')),
        for (final r in pending.value ?? const <PendingReview>[]) _ReviewCard(review: r),
      ],
    );
  }
}

class _ReviewCard extends ConsumerStatefulWidget {
  const _ReviewCard({required this.review});
  final PendingReview review;

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = widget.review;
    final state = ref.watch(adminControllerProvider);
    final ctrl = ref.read(adminControllerProvider.notifier);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EcoListTile(
            leading: EcoAvatar(text: roleEmoji(r.role)),
            title: r.name,
            subtitle: '${roleLabel(l, r.role)} · ${r.detail}',
            showDivider: false,
          ),
          if (r.role == UserRole.collector && r.documents.isEmpty) Text('⚠️ ${l.verifNoDocs}'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in r.documents)
                ActionChip(
                  avatar: const Icon(Icons.description_outlined, size: 18),
                  label: Text(d.fileName.isEmpty ? d.type : d.fileName),
                  onPressed: () => _preview(context, r.uid, d.type),
                ),
            ],
          ),
          const SizedBox(height: 10),
          EcoTextField(
            label: l.verifReasonField,
            controller: _reason,
            maxLength: 300,
            helper: l.verifReasonHelp,
          ),
          Row(
            children: [
              Expanded(
                child: EcoButton(
                  label: l.receptionReject,
                  style: EcoButtonStyle.ghost,
                  loading: state.isLoading,
                  onPressed: () async {
                    final ok = await ctrl.review(r, approve: false, reason: _reason.text);
                    if (!ok && context.mounted) showEcoToast(context, l.verifReasonRequired);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EcoButton(
                  label: l.verifApprove,
                  style: EcoButtonStyle.green,
                  loading: state.isLoading,
                  onPressed: () => ctrl.review(r, approve: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _preview(BuildContext context, String uid, String type) async {
    final bytes = await ref.read(adminRepositoryProvider).documentFile(uid, type);
    if (!context.mounted || bytes == null) return;
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (c) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(
            bytes,
            errorBuilder: (_, _, _) =>
                Padding(padding: const EdgeInsets.all(24), child: Text(context.l10n.verifNotImage)),
          ),
        ),
      ),
    );
  }
}
