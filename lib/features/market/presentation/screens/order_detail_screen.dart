import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../recycler/presentation/widgets/recycler_labels.dart';
import '../../application/market_providers.dart';
import '../../domain/market.dart';
import '../widgets/market_widgets.dart';

/// Textes de la facture et du certificat (même langue que l'écran ; le
/// PDF utilise la police embarquée).
Map<String, String> invoiceTexts(AppLocalizations l, MarketOrder o, BuildContext c) => {
  'invoice': l.docInvoice,
  'seller': l.docSeller,
  'buyer': l.docBuyer,
  'item': l.docItem,
  'qty': l.docQty,
  'unit': l.docUnitPrice,
  'amount': l.docAmount,
  'totalHt': l.docTotalHt,
  'vat': l.docVat,
  'totalTtc': l.docTotalTtc,
  'payment': l.docPayment,
  'paymentStatus': paymentLabel(l, o.payment),
  'delivery': l.docDelivery,
  'deliveryValue': l.dealInDays(o.deliveryDays),
  'footer': l.docInvoiceFooter,
};

Map<String, String> certificateTexts(AppLocalizations l) => {
  'certificate': l.docCertificate,
  'intro': l.docCertificateIntro,
  'beneficiary': l.docBeneficiary,
  'recycled': l.docRecycled,
  'co2': l.docCo2,
  'pickups': l.docPickups,
  'lot': l.reportReference,
  'material': l.reportMaterial,
  'zones': l.dashZone,
  'method': l.docCertificateMethod,
};

/// Suivi d'une commande jusqu'à la livraison (US-099 à US-101, US-104, US-105).
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final uid = ref.watch(currentUidProvider) ?? '';
    final o = ref.watch(orderProvider(id)).value;
    final state = ref.watch(marketControllerProvider);
    final ctrl = ref.read(marketControllerProvider.notifier);
    final back = IconButton.filledTonal(
      tooltip: l.commonBack,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .22),
        foregroundColor: Colors.white,
      ),
      onPressed: () => context.go(Routes.orders),
      icon: const BackButtonIcon(),
    );
    if (o == null) {
      return LayeredPage(
        header: HeroHeader(title: l.ordersTitle, leading: back),
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    final seller = o.isSeller(uid);
    final next = nextStep(o, uid);
    final material = '${materialLabel(l, o.material)} · ${formLabel(l, o.form)}';
    final myRating = seller ? o.buyerRating : o.sellerRating;
    return LayeredPage(
      header: HeroHeader(
        title: o.number,
        subtitle: '${seller ? l.orderSale : l.orderPurchase} · ${o.counterpartName(uid)}',
        emoji: seller ? '📤' : '📥',
        gradient: o.status == OrderStatus.cancelled ? EcoGradients.coral : EcoGradients.sky,
        leading: back,
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${materialEmoji(o.material)} $material',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${l.kg(fmtKg(context, o.quantityKg))} × ${l.pricePerKg(fmtDt(context, o.priceDtPerKg))} · ${l.dealInDays(o.deliveryDays)}',
              ),
              const SizedBox(height: 6),
              Text(
                l.dt(fmtDt(context, o.totalTtc)),
                style: AppTheme.weighted(24, 800, color: EcoColors.primary),
              ),
              Text(
                l.orderVatDetail(fmtDt(context, o.totalHt), fmtDt(context, o.vat)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  EcoChip(label: orderStatusLabel(l, o.status), tone: ChipTone.sky),
                  EcoChip(label: '💳 ${paymentLabel(l, o.payment)}', tone: ChipTone.sun),
                ],
              ),
            ],
          ),
        ),
        if (o.status == OrderStatus.cancelled)
          EcoCard(child: Text('⛔ ${l.orderCancelled}'))
        else
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: OrderTimeline(order: o),
          ),
        if (next != null)
          EcoButton(
            label: nextStepLabel(l, next),
            style: EcoButtonStyle.green,
            loading: state.isLoading,
            onPressed: () => ctrl.advance(o),
          ),
        if (o.status != OrderStatus.cancelled &&
            ((!seller && o.payment == PaymentStatus.pending) ||
                (seller && o.payment != PaymentStatus.received)))
          EcoButton(
            label: seller ? l.paymentConfirm : l.paymentDeclare,
            leading: '💳',
            style: EcoButtonStyle.ghost,
            loading: state.isLoading,
            onPressed: () => ctrl.payment(o),
          ),
        EcoCard(child: Text('ℹ️ ${l.paymentExplain}')),
        ResponsiveGrid(
          children: [
            EcoButton(
              label: l.docInvoice,
              leading: '🧾',
              style: EcoButtonStyle.ghost,
              loading: state.isLoading,
              onPressed: () => ctrl.exportInvoice(
                o,
                invoiceTexts(l, o, context),
                material: material,
                date: fmtDate(context, o.createdAt ?? DateTime.now()),
              ),
            ),
            if (o.status == OrderStatus.delivered || o.status == OrderStatus.completed)
              EcoButton(
                label: l.docCertificate,
                leading: '🏅',
                style: EcoButtonStyle.ghost,
                loading: state.isLoading,
                onPressed: () => ctrl.exportCertificate(
                  [orderAsLot(o)],
                  certificateTexts(l),
                  company: o.sellerName,
                  number: o.number,
                  date: fmtDate(context, DateTime.now()),
                  materialOf: (_) => material,
                  beneficiary: o.buyerName,
                  pickups: o.originPickups,
                  referenceOf: (_) => o.number,
                  fmt: (v) => fmtKg(context, v),
                ),
              ),
          ],
        ),
        if (o.status == OrderStatus.completed)
          EcoCard(
            child: Column(
              children: [
                Text(
                  l.rateTitle(o.counterpartName(uid)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (myRating != null)
                  Text('⭐' * myRating, style: const TextStyle(fontSize: 28))
                else
                  StarPicker(
                    onPick: (s) async {
                      if (await ctrl.rate(o, s) && context.mounted) {
                        showEcoToast(context, l.rateThanks);
                      }
                    },
                  ),
              ],
            ),
          ),
        if (canCancel(o))
          EcoLink(
            label: '✖️ ${l.orderCancel}',
            color: const Color(0xFFC4482A),
            onPressed: () => ctrl.cancel(o),
          ),
        EcoLink(label: '💬 ${l.dealOpen}', onPressed: () => context.go(Routes.deal(o.dealId))),
      ],
    );
  }
}
