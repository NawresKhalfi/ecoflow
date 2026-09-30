import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/wallet_providers.dart';
import '../../data/wallet_repository.dart';
import '../../domain/rewards.dart';
import '../../domain/wallet.dart';
import '../widgets/wallet_labels.dart';

/// Catalogue de récompenses partenaires (US-072) et échange (US-073).
class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  RewardKind? _kind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wallet = ref.watch(myWalletProvider).value ?? const Wallet();
    final all = ref.watch(rewardsProvider).value ?? const <Reward>[];
    final rewards = all.where((r) => r.active && (_kind == null || r.kind == _kind)).toList();
    return LayeredPage(
      header: HeroHeader(
        title: l.rewardsTitle,
        subtitle: l.rewardsSubtitle(fmtPoints(context, wallet.balance)),
        emoji: '🎁',
        gradient: EcoGradients.sun,
        leading: _BackButton(onPressed: () => context.go(Routes.wallet)),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            EcoChip(
              label: l.rewardsAll,
              selected: _kind == null,
              onTap: () => setState(() => _kind = null),
            ),
            for (final k in RewardKind.values)
              EcoChip(
                label: rewardKindLabel(l, k),
                selected: _kind == k,
                onTap: () => setState(() => _kind = k),
              ),
          ],
        ),
        if (rewards.isEmpty) EcoCard(child: Text(l.rewardsEmpty)),
        ResponsiveGrid(
          children: [for (final r in rewards) _RewardCard(reward: r, wallet: wallet)],
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: context.l10n.commonBack,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .22),
      foregroundColor: Colors.white,
    ),
    onPressed: onPressed,
    icon: const BackButtonIcon(),
  );
}

class _RewardCard extends ConsumerWidget {
  const _RewardCard({required this.reward, required this.wallet});
  final Reward reward;
  final Wallet wallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final refusal = redeemRefusal(reward, wallet.balance, frozen: wallet.frozen);
    final state = ref.watch(walletControllerProvider);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EcoAvatar(text: reward.emoji, gradient: EcoGradients.sun, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reward.title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${reward.partnerName} · ${rewardKindLabel(l, reward.kind)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (reward.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(reward.description),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                l.points(fmtPoints(context, reward.cost)),
                style: AppTheme.weighted(20, 800, color: EcoColors.violetDeep),
              ),
              const Spacer(),
              if (reward.stock != null)
                EcoChip(label: l.rewardStock(reward.stock!), tone: ChipTone.sky),
            ],
          ),
          const SizedBox(height: 10),
          EcoButton(
            label: refusal == null ? l.rewardRedeem : refusalLabel(l, refusal),
            style: EcoButtonStyle.green,
            loading: state.isLoading,
            onPressed: refusal == null ? () => _confirm(context, ref) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(reward.title),
        content: Text(l.rewardConfirm(fmtPoints(context, reward.cost), reward.partnerName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.rewardRedeem)),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final ctrl = ref.read(walletControllerProvider.notifier);
    final ok = await ctrl.redeem(reward);
    if (!context.mounted) return;
    final err = ref.read(walletControllerProvider).error;
    if (ok) {
      showEcoToast(context, l.rewardRedeemed);
      context.go(Routes.walletCoupons);
    } else {
      showEcoToast(context, err is RedeemRefused ? refusalLabel(l, err.reason) : l.errSaveFailed);
    }
  }
}
