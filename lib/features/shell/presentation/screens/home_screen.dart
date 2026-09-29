import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/domain/verification_status.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/role_picker.dart';
import '../../../profile/presentation/widgets/verification_widgets.dart';

/// Accueil de l'espace du rôle. Écran de transition minimal en attendant
/// les epics métier (scan, missions, stocks, pilotage).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(sessionProvider).profile;
    if (profile == null) return const SizedBox.shrink();
    final role = profile.role;
    final subtitle = switch (role) {
      UserRole.citizen => l.homeCitizenSubtitle,
      UserRole.collector => l.homeCollectorSubtitle,
      UserRole.recycler => l.homeRecyclerSubtitle,
      UserRole.admin => l.homeAdminSubtitle,
    };
    return LayeredPage(
      header: HeroHeader(
        title: l.homeHello(profile.firstName),
        subtitle: subtitle,
        gradient: roleGradient(role),
        emoji: roleEmoji(role),
        trailing: EcoChip(label: '${roleEmoji(role)} ${roleLabel(l, role)}', tone: ChipTone.sun),
      ),
      children: [
        if (role.requiresVerification)
          VerificationCard(
            role: role,
            status: profile.verificationStatus,
            rejectionReason: profile.rejectionReason,
          ),
        if (role == UserRole.collector && profile.verificationStatus == VerificationStatus.approved)
          EcoCard(
            gradient: EcoGradients.coral,
            decorated: true,
            onTap: () => context.go(Routes.weighing),
            semanticLabel: l.homeWeighCta,
            child: Row(
              children: [
                const ExcludeSemantics(child: Text('⚖️', style: TextStyle(fontSize: 40))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.homeWeighCta, style: AppTheme.weighted(20, 800, color: Colors.white)),
                      Text(
                        l.homeWeighCtaBody,
                        style: AppTheme.weighted(
                          14,
                          500,
                          color: Colors.white.withValues(alpha: .92),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        if (role == UserRole.citizen)
          EcoCard(
            gradient: EcoGradients.coral,
            decorated: true,
            onTap: () => context.go(Routes.scan),
            semanticLabel: l.homeScanCta,
            child: Row(
              children: [
                const ExcludeSemantics(child: Text('📸', style: TextStyle(fontSize: 40))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.homeScanCta, style: AppTheme.weighted(20, 800, color: Colors.white)),
                      Text(
                        l.homeScanCtaBody,
                        style: AppTheme.weighted(
                          14,
                          500,
                          color: Colors.white.withValues(alpha: .92),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        if (role == UserRole.citizen)
          Row(
            children: [
              Expanded(
                child: StatTile(emoji: '♻️', value: '0', label: l.statKg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  emoji: '🚚',
                  value: '0',
                  label: l.statCollections,
                  gradient: EcoGradients.sky,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  emoji: '🏅',
                  value: '0',
                  label: l.statPoints,
                  gradient: EcoGradients.violet,
                ),
              ),
            ],
          ),
        ResponsiveGrid(
          children: [
            EcoCard(
              gradient: EcoGradients.coral,
              decorated: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.homeComingTitle, style: AppTheme.weighted(20, 800, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(
                    l.homeComingBody,
                    style: AppTheme.weighted(15, 500, color: Colors.white.withValues(alpha: .92)),
                  ),
                ],
              ),
            ),
            EcoCard(
              onTap: () => context.go(Routes.profile),
              child: Row(
                children: [
                  EcoAvatar(text: profile.initials, gradient: roleGradient(role), size: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          profile.email ?? profile.phoneNumber ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        EcoChip(label: l.profileTitle),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.eco.muted),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
