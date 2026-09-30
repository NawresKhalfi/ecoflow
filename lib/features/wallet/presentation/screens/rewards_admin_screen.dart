import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/wallet_providers.dart';
import '../../domain/rewards.dart';
import '../widgets/reward_forms.dart';
import '../widgets/wallet_labels.dart';

/// Partenaires, offres (US-074) et validation des coupons (US-073).
class RewardsAdminScreen extends ConsumerWidget {
  const RewardsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final partners = ref.watch(partnersProvider).value ?? const <Partner>[];
    final rewards = ref.watch(rewardsProvider).value ?? const <Reward>[];
    return LayeredPage(
      header: HeroHeader(
        title: l.rewardsAdminTitle,
        subtitle: l.rewardsAdminSubtitle,
        emoji: '🤝',
        gradient: EcoGradients.sun,
      ),
      children: [
        const _CouponCheckCard(),
        SectionTitle('🏪 ${l.partnersTitle}'),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final p in partners)
                EcoListTile(
                  leading: EcoAvatar(text: p.emoji),
                  title: p.name,
                  subtitle: [
                    if (p.city.isNotEmpty) p.city,
                    l.partnerOffers(rewards.where((r) => r.partnerId == p.id).length),
                    if (!p.active) l.adminInactive,
                  ].join(' · '),
                  onTap: () => showPartnerForm(context, existing: p),
                ),
              EcoLink(label: '＋ ${l.partnerAdd}', onPressed: () => showPartnerForm(context)),
            ],
          ),
        ),
        SectionTitle('🎁 ${l.rewardsTitle}'),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final r in rewards)
                EcoListTile(
                  leading: EcoAvatar(text: r.emoji),
                  title: r.title,
                  subtitle: [
                    r.partnerName,
                    l.points(fmtPoints(context, r.cost)),
                    if (r.stock != null) l.rewardStock(r.stock!),
                    if (!r.active) l.adminInactive,
                  ].join(' · '),
                  onTap: () => showRewardForm(context, partners, existing: r),
                ),
              if (partners.isEmpty)
                Padding(padding: const EdgeInsets.all(8), child: Text(l.rewardNeedPartner))
              else
                EcoLink(
                  label: '＋ ${l.rewardAdd}',
                  onPressed: () => showRewardForm(context, partners),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CouponCheckCard extends ConsumerStatefulWidget {
  const _CouponCheckCard();

  @override
  ConsumerState<_CouponCheckCard> createState() => _CouponCheckCardState();
}

class _CouponCheckCardState extends ConsumerState<_CouponCheckCard> {
  final _code = TextEditingController();
  bool _searched = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(walletAdminControllerProvider);
    final ctrl = ref.read(walletAdminControllerProvider.notifier);
    final found = ctrl.found;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🎟️ ${l.couponCheckTitle}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          EcoTextField(label: l.couponCode, controller: _code, hint: 'ABCD-EF23'),
          const SizedBox(height: 8),
          EcoButton(
            label: l.couponCheck,
            style: EcoButtonStyle.ghost,
            loading: state.isLoading,
            onPressed: () async {
              await ctrl.findCoupon(_code.text);
              setState(() => _searched = true);
            },
          ),
          if (_searched && found == null) ...[const SizedBox(height: 8), Text(l.couponNotFound)],
          if (found != null) ...[
            const SizedBox(height: 10),
            EcoListTile(
              leading: const EcoAvatar(text: '🎁'),
              title: found.rewardTitle,
              subtitle: '${found.partnerName} · ${couponStatusLabel(l, found.status)}',
              showDivider: false,
            ),
            if (found.status == RedemptionStatus.active)
              EcoButton(
                label: l.couponMarkUsed,
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: () async {
                  if (await ctrl.markUsed(found) && context.mounted) {
                    setState(() => _searched = false);
                    _code.clear();
                    showEcoToast(context, l.couponMarkedUsed);
                  }
                },
              ),
          ],
        ],
      ),
    );
  }
}
