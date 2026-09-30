import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../collection/presentation/widgets/presence_card.dart';
import '../../../tracking/application/tracking_providers.dart';
import '../../../missions/presentation/widgets/work_zone_card.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/domain/verification_status.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/role_picker.dart';
import '../../../profile/presentation/widgets/verification_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../wallet/application/wallet_providers.dart';
import '../../../wallet/domain/wallet.dart';
import '../../../wallet/presentation/widgets/wallet_labels.dart';

/// Accueil de l'espace du rôle. Écran de transition minimal en attendant
/// les epics métier (scan, missions, stocks, pilotage).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(sessionProvider).profile;
    if (profile == null) return const SizedBox.shrink();
    final unread = ref.watch(unreadCountProvider);
    final role = profile.role;
    final wallet = role == UserRole.citizen
        ? ref.watch(myWalletProvider).value ?? const Wallet()
        : const Wallet();
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
          const PresenceCard(),
        if (role == UserRole.collector && profile.verificationStatus == VerificationStatus.approved)
          const WorkZoneCard(),
        if (role == UserRole.collector && profile.verificationStatus == VerificationStatus.approved)
          EcoCard(
            gradient: EcoGradients.coral,
            decorated: true,
            onTap: () => context.go(Routes.missions),
            semanticLabel: l.homeMissionsCta,
            child: Row(
              children: [
                const ExcludeSemantics(child: Text('🚚', style: TextStyle(fontSize: 40))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.homeMissionsCta,
                        style: AppTheme.weighted(20, 800, color: Colors.white),
                      ),
                      Text(
                        l.homeMissionsCtaBody,
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
        if (role == UserRole.admin) const _AdminWalletCard(),
        if (role == UserRole.admin)
          EcoCard(
            gradient: EcoGradients.violet,
            decorated: true,
            onTap: () => context.go(Routes.optimization),
            semanticLabel: l.homeOptimizationCta,
            child: Row(
              children: [
                const ExcludeSemantics(child: Text('⚙️', style: TextStyle(fontSize: 40))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.homeOptimizationCta,
                        style: AppTheme.weighted(20, 800, color: Colors.white),
                      ),
                      Text(
                        l.homeOptimizationCtaBody,
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
                child: StatTile(emoji: '♻️', value: fmtKg(context, wallet.kg), label: l.statKg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  emoji: '🚚',
                  value: '${wallet.collections}',
                  label: l.statCollections,
                  gradient: EcoGradients.sky,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  onTap: () => context.go(Routes.wallet),
                  child: GestureDetector(
                    onTap: () => context.go(Routes.wallet),
                    child: StatTile(
                      emoji: '🏅',
                      value: fmtPoints(context, wallet.balance),
                      label: l.statPoints,
                      gradient: EcoGradients.violet,
                    ),
                  ),
                ),
              ),
            ],
          ),
        if (role == UserRole.citizen)
          EcoCard(
            onTap: () => context.go(Routes.estimates),
            child: Row(
              children: [
                const EcoAvatar(text: '🧾'),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(l.navEstimates, style: Theme.of(context).textTheme.titleMedium),
                ),
                Icon(Icons.chevron_right, color: context.eco.muted),
              ],
            ),
          ),
        EcoCard(
          onTap: () => context.go(Routes.inbox),
          semanticLabel: l.homeInboxCta,
          child: Row(
            children: [
              EcoAvatar(text: '🔔', gradient: unread > 0 ? EcoGradients.coral : null),
              const SizedBox(width: 12),
              Expanded(child: Text(l.homeInboxCta, style: Theme.of(context).textTheme.titleMedium)),
              EcoChip(
                label: l.inboxUnread(unread),
                tone: unread > 0 ? ChipTone.coral : ChipTone.green,
              ),
            ],
          ),
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

/// Raccourcis de l'administration du Recycle Wallet (US-071, US-074, US-075).
class _AdminWalletCard extends ConsumerWidget {
  const _AdminWalletCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final held = ref.watch(heldEntriesProvider).value?.length ?? 0;
    return EcoCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          EcoListTile(
            leading: const EcoAvatar(text: '🏅', gradient: EcoGradients.violet),
            title: l.pointsRulesTitle,
            subtitle: l.pointsRulesSubtitle,
            onTap: () => context.go(Routes.pointsRules),
          ),
          EcoListTile(
            leading: const EcoAvatar(text: '🤝', gradient: EcoGradients.sun),
            title: l.rewardsAdminTitle,
            subtitle: l.rewardsAdminSubtitle,
            onTap: () => context.go(Routes.rewardsAdmin),
          ),
          EcoListTile(
            leading: const EcoAvatar(text: '🛡️', gradient: EcoGradients.coral),
            title: l.fraudTitle,
            subtitle: l.fraudPending(held),
            trailing: held > 0 ? EcoChip(label: '$held', tone: ChipTone.coral) : null,
            onTap: () => context.go(Routes.fraud),
            showDivider: false,
          ),
        ],
      ),
    );
  }
}
