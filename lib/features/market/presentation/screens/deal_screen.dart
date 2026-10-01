import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/market_providers.dart';
import '../../domain/market.dart';

/// Négociation sécurisée (US-097, US-098) : messages (coordonnées
/// masquées) et propositions chiffrées ; l'acceptation crée la commande.
class DealScreen extends ConsumerStatefulWidget {
  const DealScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<DealScreen> createState() => _DealScreenState();
}

class _DealScreenState extends ConsumerState<DealScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final uid = ref.watch(currentUidProvider) ?? '';
    final deal = ref.watch(dealProvider(widget.id)).value;
    final listing = deal == null ? null : ref.watch(listingProvider(deal.listingId)).value;
    final messages = ref.watch(dealMessagesProvider(widget.id)).value ?? const <MarketMessage>[];
    final state = ref.watch(marketControllerProvider);
    final ctrl = ref.read(marketControllerProvider.notifier);
    return LayeredPage(
      header: HeroHeader(
        title: deal?.otherName(uid) ?? l.marketDeals,
        subtitle: deal?.listingTitle,
        emoji: '💼',
        gradient: EcoGradients.violet,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () =>
              context.go(deal == null ? Routes.market : Routes.listing(deal.listingId)),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.dealPrivacy, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              if (messages.isEmpty) Text(l.dealEmpty),
              for (final m in messages)
                _Bubble(message: m, mine: m.fromUid == uid, deal: deal, listing: listing),
              const SizedBox(height: 8),
              EcoTextField(label: l.chatHint, controller: _text, maxLength: maxMarketMessage),
              Row(
                children: [
                  Expanded(
                    child: EcoButton(
                      label: l.chatSend,
                      style: EcoButtonStyle.ghost,
                      loading: state.isLoading,
                      onPressed: deal == null
                          ? null
                          : () async {
                              if (await ctrl.sendText(deal, _text.text)) _text.clear();
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: EcoButton(
                      label: l.dealPropose,
                      leading: '💼',
                      style: EcoButtonStyle.green,
                      onPressed:
                          deal == null || listing == null || listing.status != ListingStatus.open
                          ? null
                          : () => _propose(context, deal, listing),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _propose(BuildContext context, Deal deal, Listing listing) async {
    final l = context.l10n;
    final price = TextEditingController(text: listing.priceDtPerKg?.toString() ?? '');
    final qty = TextEditingController(text: listing.quantityKg.toStringAsFixed(0));
    final days = TextEditingController(text: '7');
    double? n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim());
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + MediaQuery.viewInsetsOf(c).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.dealPropose, style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 10),
            EcoTextField(
              label: l.listingPrice,
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 10),
            EcoTextField(label: l.listingQty, controller: qty, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            EcoTextField(label: l.dealDays, controller: days, keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            EcoButton(
              label: l.dealSendProposal,
              style: EcoButtonStyle.green,
              onPressed: () => Navigator.pop(c, true),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final sent = await ref
          .read(marketControllerProvider.notifier)
          .propose(
            deal,
            price: n(price) ?? 0,
            quantity: n(qty) ?? 0,
            days: int.tryParse(days.text.trim()) ?? -1,
          );
      if (!sent && context.mounted) showEcoToast(context, l.dealInvalid);
    }
    for (final c in [price, qty, days]) {
      c.dispose();
    }
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.mine, this.deal, this.listing});
  final MarketMessage message;
  final bool mine;
  final Deal? deal;
  final Listing? listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final m = message;
    final uid = ref.watch(currentUidProvider) ?? '';
    final ctrl = ref.read(marketControllerProvider.notifier);
    final eco = context.eco;
    final proposal = m.kind == MessageKind.proposal;
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: proposal
              ? EcoColors.sun.withValues(alpha: .18)
              : (mine ? EcoColors.primary : eco.card),
          border: proposal ? Border.all(color: EcoColors.sunDeep) : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (proposal) ...[
              Text('💼 ${l.dealProposal}', style: AppTheme.weighted(13, 700)),
              Text(
                '${l.pricePerKg(fmtDt(context, m.priceDtPerKg!))} × ${l.kg(fmtKg(context, m.quantityKg!))}',
                style: AppTheme.weighted(17, 800),
              ),
              Text(
                '${l.dealTotal(fmtDt(context, m.totalDt))} · ${l.dealInDays(m.deliveryDays ?? 0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (m.text.isNotEmpty) Text(m.text),
              const SizedBox(height: 6),
              if (m.canAnswer(uid) && deal != null && listing != null)
                // Les boutons passent à la ligne si la bulle est étroite.
                OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => ctrl.answer(deal!, listing!, m, accept: false),
                      child: Text(l.dealDecline),
                    ),
                    FilledButton(
                      onPressed: () async {
                        if (await ctrl.answer(deal!, listing!, m, accept: true) &&
                            context.mounted) {
                          context.go(Routes.order(ctrl.lastId!));
                        }
                      },
                      child: Text(l.dealAccept),
                    ),
                  ],
                )
              else if (m.status == ProposalStatus.pending && mine && deal != null)
                TextButton(onPressed: () => ctrl.withdraw(deal!, m), child: Text(l.dealWithdraw))
              else
                EcoChip(
                  label: switch (m.status) {
                    ProposalStatus.pending => l.dealPending,
                    ProposalStatus.accepted => l.dealAccepted,
                    ProposalStatus.declined => l.dealDeclined,
                    ProposalStatus.withdrawn => l.dealWithdrawn,
                  },
                  tone: m.status == ProposalStatus.accepted ? ChipTone.green : ChipTone.sun,
                ),
              if (m.status == ProposalStatus.accepted)
                EcoLink(
                  label: '📦 ${l.dealSeeOrder}',
                  onPressed: () => context.go(Routes.order(m.id)),
                ),
            ] else
              Text(m.text, style: TextStyle(color: mine ? Colors.white : null)),
          ],
        ),
      ),
    );
  }
}
