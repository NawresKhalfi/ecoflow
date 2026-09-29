import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/domain/verification_status.dart';

/// Pastille de statut « à envoyer / en attente / validé / refusé ».
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final VerificationStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, tone) = switch (status) {
      VerificationStatus.pending => ('⏳ ${l.statusPending}', ChipTone.sun),
      VerificationStatus.approved => ('✓ ${l.statusApproved}', ChipTone.green),
      VerificationStatus.rejected => ('✕ ${l.statusRejected}', ChipTone.coral),
      _ => (l.statusNotSubmitted, ChipTone.sky),
    };
    return EcoChip(label: label, tone: tone);
  }
}

/// Carte de vérification du professionnel (US-006 / US-007) : statut
/// visible, motif de refus affiché, accès au dossier.
class VerificationCard extends StatelessWidget {
  const VerificationCard({
    super.key,
    required this.role,
    required this.status,
    this.rejectionReason,
  });

  final UserRole role;
  final VerificationStatus status;
  final String? rejectionReason;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final collector = role == UserRole.collector;
    final message = switch (status) {
      VerificationStatus.pending => l.verifPending,
      VerificationStatus.approved => l.verifApproved,
      VerificationStatus.rejected => l.verifRejected,
      _ => collector ? l.verifNotSubmittedCollector : l.verifNotSubmittedRecycler,
    };
    final gradient = switch (status) {
      VerificationStatus.approved => EcoGradients.green,
      VerificationStatus.rejected => EcoGradients.coral,
      VerificationStatus.pending => EcoGradients.sun,
      _ => EcoGradients.violet,
    };
    final fg = status == VerificationStatus.pending ? EcoColors.onSun : Colors.white;
    return EcoCard(
      gradient: gradient,
      decorated: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('🛡️ ${l.verifTitle}', style: AppTheme.weighted(18, 800, color: fg))),
          StatusChip(status),
        ]),
        const SizedBox(height: 8),
        Text(message, style: AppTheme.weighted(15, 500, color: fg)),
        if (status == VerificationStatus.rejected && (rejectionReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(l.verifReason(rejectionReason!), style: AppTheme.weighted(15, 700, color: fg)),
        ],
        if (status.canSubmit) ...[
          const SizedBox(height: 14),
          EcoButton(
            label: collector ? l.verifActionCollector : l.verifActionRecycler,
            style: EcoButtonStyle.ghost,
            expand: false,
            onPressed: () => context.go(collector ? Routes.documents : Routes.company),
          ),
        ],
      ]),
    );
  }
}
