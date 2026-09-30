import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/wallet_providers.dart';
import '../../domain/gamification.dart';
import '../../domain/points_rules.dart';
import '../../domain/wallet.dart';
import '../widgets/wallet_cards.dart';
import '../widgets/wallet_labels.dart';

/// Recycle Wallet du citoyen (US-070, US-076 à US-078).
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(walletSyncProvider);
    final wallet = ref.watch(myWalletProvider).value ?? const Wallet();
    final entries = ref.watch(myEntriesProvider).value ?? const <LedgerEntry>[];
    final rules = ref.watch(pointsRulesProvider).value ?? const PointsRules();
    final level = levelFor(wallet.earned);
    return LayeredPage(
      header: HeroHeader(
        title: l.walletTitle,
        subtitle: l.walletSubtitle,
        emoji: '👛',
        gradient: EcoGradients.violet,
        trailing: EcoChip(label: '${level.emoji} ${levelLabel(l, level)}', tone: ChipTone.sun),
      ),
      children: [
        if (wallet.frozen) FrozenBanner(wallet: wallet),
        BalanceCard(wallet: wallet),
        if (wallet.held > 0) EcoCard(child: Text('⏳ ${l.walletHeldInfo}')),
        ResponsiveGrid(
          children: [
            EcoButton(
              label: l.rewardsTitle,
              leading: '🎁',
              onPressed: () => context.go(Routes.walletRewards),
            ),
            EcoButton(
              label: l.couponsTitle,
              leading: '🎟️',
              style: EcoButtonStyle.ghost,
              onPressed: () => context.go(Routes.walletCoupons),
            ),
          ],
        ),
        LevelCard(wallet: wallet),
        BadgesCard(earned: earnedBadges(wallet, entries)),
        ReferralCard(wallet: wallet, rules: rules),
        ExpiryCard(wallet: wallet, entries: entries, rules: rules),
        SectionTitle(l.walletHistory),
        HistoryCard(entries: entries),
        EcoCard(child: Text('ℹ️ ${l.walletHowItWorks(rules.pointsPerKg.round())}')),
      ],
    );
  }
}
