import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/wallet_providers.dart';
import '../../domain/rewards.dart';
import '../widgets/wallet_labels.dart';

/// Coupons obtenus, à présenter chez le partenaire (US-073).
class CouponsScreen extends ConsumerWidget {
  const CouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final coupons = ref.watch(myRedemptionsProvider).value ?? const <Redemption>[];
    return LayeredPage(
      header: HeroHeader(
        title: l.couponsTitle,
        subtitle: l.couponsSubtitle,
        emoji: '🎟️',
        gradient: EcoGradients.sky,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.wallet),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        if (coupons.isEmpty) EcoCard(child: Text(l.couponsEmpty)),
        ResponsiveGrid(children: [for (final c in coupons) CouponCard(coupon: c)]),
      ],
    );
  }
}

class CouponCard extends StatelessWidget {
  const CouponCard({super.key, required this.coupon});
  final Redemption coupon;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final active = coupon.status == RedemptionStatus.active;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coupon.rewardTitle, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${coupon.partnerName} · ${l.points(fmtPoints(context, coupon.cost))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              EcoChip(
                label: couponStatusLabel(l, coupon.status),
                tone: active ? ChipTone.green : ChipTone.sun,
              ),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: coupon.qrPayload,
                  size: 150,
                  semanticsLabel: l.couponQr(coupon.code),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: SelectableText(
                coupon.code,
                style: AppTheme.weighted(24, 800, color: EcoColors.primary),
              ),
            ),
            Text(
              l.couponHowTo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else if (coupon.usedAt != null)
            Text(l.couponUsedOn(fmtDate(context, coupon.usedAt!))),
        ],
      ),
    );
  }
}
