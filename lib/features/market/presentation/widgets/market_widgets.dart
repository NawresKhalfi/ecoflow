import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../recycler/presentation/widgets/recycler_labels.dart';
import '../../application/market_providers.dart';
import '../../domain/market.dart';

String orderStatusLabel(AppLocalizations l, OrderStatus s) => switch (s) {
  OrderStatus.confirmed => l.orderConfirmed,
  OrderStatus.preparing => l.orderPreparing,
  OrderStatus.shipped => l.orderShipped,
  OrderStatus.delivered => l.orderDelivered,
  OrderStatus.completed => l.orderCompleted,
  OrderStatus.cancelled => l.orderCancelled,
};

String nextStepLabel(AppLocalizations l, OrderStatus s) => switch (s) {
  OrderStatus.preparing => l.orderDoPrepare,
  OrderStatus.shipped => l.orderDoShip,
  OrderStatus.delivered => l.orderDoDeliver,
  OrderStatus.completed => l.orderDoComplete,
  _ => '',
};

String paymentLabel(AppLocalizations l, PaymentStatus p) => switch (p) {
  PaymentStatus.pending => l.paymentPending,
  PaymentStatus.declared => l.paymentDeclared,
  PaymentStatus.received => l.paymentReceived,
};

String reasonLabel(AppLocalizations l, ReportReason r) => switch (r) {
  ReportReason.misleading => l.reportMisleading,
  ReportReason.prohibited => l.reportProhibited,
  ReportReason.duplicate => l.reportDuplicate,
  ReportReason.spam => l.reportSpam,
  ReportReason.other => l.reportOther,
};

String listingStatusLabel(AppLocalizations l, ListingStatus s) => switch (s) {
  ListingStatus.open => l.listingOpen,
  ListingStatus.closed => l.listingClosed,
  ListingStatus.suspended => l.listingSuspended,
  ListingStatus.removed => l.listingRemoved,
};

/// « 500 kg PET · Paillettes » : titre court d'une annonce.
String listingTitle(AppLocalizations l, BuildContext c, Listing x) =>
    '${l.kg(fmtKg(c, x.quantityKg))} ${materialLabel(l, x.material)} · ${formLabel(l, x.form)}';

class ListingCard extends ConsumerWidget {
  const ListingCard({super.key, required this.listing, this.onTap, this.extra});
  final Listing listing;
  final VoidCallback? onTap;
  final String? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final x = listing;
    final buy = x.type == ListingType.buy;
    final rating = ref.watch(companyRatingProvider(x.ownerUid)).value;
    return EcoCard(
      onTap: onTap,
      semanticLabel: '${buy ? l.listingBuy : l.listingSell} · ${listingTitle(l, context, x)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EcoChip(label: buy ? '🔎 ${l.listingBuy}' : '🏷️ ${l.listingSell}', tone: buy ? ChipTone.sky : ChipTone.green),
              const Spacer(),
              if (x.status != ListingStatus.open)
                EcoChip(label: listingStatusLabel(l, x.status), tone: ChipTone.sun),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${materialEmoji(x.material)} ${listingTitle(l, context, x)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            [
              '📍 ${x.city}',
              '📅 ${(buy ? l.listingNeededBy : l.listingAvailableUntil)(fmtDate(context, x.deadline))}',
              if (x.grade != null) gradeLabel(l, x.grade!),
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${x.ownerName}${rating == null ? '' : ' · ⭐ ${rating.avg.toStringAsFixed(1)} (${rating.count})'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (x.priceDtPerKg != null)
                Text(
                  '${buy ? '≤ ' : ''}${l.pricePerKg(fmtDt(context, x.priceDtPerKg!))}',
                  style: AppTheme.weighted(16, 800, color: EcoColors.primary),
                ),
            ],
          ),
          if (extra != null) ...[const SizedBox(height: 6), EcoChip(label: extra!, tone: ChipTone.violet)],
        ],
      ),
    );
  }
}

/// Sélection d'une note de 1 à 5 étoiles (US-101).
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.onPick});
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: l.rateStars(i),
            onPressed: () => onPick(i),
            icon: const Icon(Icons.star_rounded, size: 36, color: EcoColors.sunDeep),
          ),
      ],
    );
  }
}

/// Avancement d'une commande, de la confirmation à la fin (US-100).
class OrderTimeline extends StatelessWidget {
  const OrderTimeline({super.key, required this.order});
  final MarketOrder order;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    const steps = [
      OrderStatus.confirmed,
      OrderStatus.preparing,
      OrderStatus.shipped,
      OrderStatus.delivered,
      OrderStatus.completed,
    ];
    final reached = order.status == OrderStatus.cancelled ? -1 : steps.indexOf(order.status);
    return Column(
      children: [
        for (final (i, s) in steps.indexed)
          EcoListTile(
            leading: EcoAvatar(
              text: i <= reached ? '✅' : '⚪',
              gradient: i <= reached ? EcoGradients.green : null,
              size: 36,
            ),
            title: orderStatusLabel(l, s),
            subtitle: order.history[s] == null ? null : fmtDate(context, order.history[s]!),
            showDivider: i < steps.length - 1,
          ),
      ],
    );
  }
}
