import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/market_providers.dart';
import '../../domain/market.dart';
import '../widgets/listing_form.dart';
import '../widgets/market_widgets.dart';

/// Détail d'une annonce : négocier, signaler ; côté auteur, négociations
/// reçues, modification, clôture (US-097, US-103).
class ListingDetailScreen extends ConsumerWidget {
  const ListingDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final x = ref.watch(listingProvider(id)).value;
    final uid = ref.watch(currentUidProvider);
    final state = ref.watch(marketControllerProvider);
    final ctrl = ref.read(marketControllerProvider.notifier);
    final deals = (ref.watch(myDealsProvider).value ?? const <Deal>[])
        .where((d) => d.listingId == id)
        .toList();
    final back = IconButton.filledTonal(
      tooltip: l.commonBack,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .22),
        foregroundColor: Colors.white,
      ),
      onPressed: () => context.go(Routes.market),
      icon: const BackButtonIcon(),
    );
    if (x == null) {
      return LayeredPage(
        header: HeroHeader(title: l.marketTitle, leading: back),
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    final mine = x.ownerUid == uid;
    // Écouté (et non lu) : le profil entreprise doit être chargé pour
    // donner son nom au fil de négociation.
    final myName =
        ref.watch(companyProfileProvider).value?.legalName ??
        ref.watch(currentProfileProvider).value?.displayName ??
        '';
    return LayeredPage(
      header: HeroHeader(
        title: x.type == ListingType.buy ? l.listingBuy : l.listingSell,
        subtitle: x.ownerName,
        emoji: x.type == ListingType.buy ? '🔎' : '🏷️',
        gradient: x.type == ListingType.buy ? EcoGradients.sky : EcoGradients.green,
        leading: back,
      ),
      children: [
        ListingCard(listing: x),
        if (x.description.isNotEmpty) EcoCard(child: Text(x.description)),
        if (!mine && x.status == ListingStatus.open) ...[
          EcoButton(
            label: x.type == ListingType.buy ? l.dealRespond : l.dealNegotiate,
            leading: '💬',
            style: EcoButtonStyle.green,
            loading: state.isLoading,
            onPressed: () async {
              if (await ctrl.openDeal(x, myName, listingTitle(l, context, x)) && context.mounted) {
                context.go(Routes.deal(ctrl.lastId!));
              }
            },
          ),
          EcoLink(
            label: '🚩 ${l.reportListing}',
            color: const Color(0xFFC4482A),
            onPressed: () => _report(context, ref, x),
          ),
        ],
        if (mine) ...[
          SectionTitle('💬 ${l.marketDeals}'),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: deals.isEmpty
                ? Padding(padding: const EdgeInsets.all(8), child: Text(l.marketDealsEmpty))
                : Column(
                    children: [
                      for (final (i, d) in deals.indexed)
                        EcoListTile(
                          leading: EcoAvatar(
                            text: d.counterpartName.isEmpty ? '?' : d.counterpartName[0],
                          ),
                          title: d.counterpartName,
                          subtitle: d.lastMessage,
                          onTap: () => context.go(Routes.deal(d.id)),
                          showDivider: i < deals.length - 1,
                        ),
                    ],
                  ),
          ),
          if (x.status == ListingStatus.open || x.status == ListingStatus.closed)
            ResponsiveGrid(
              children: [
                EcoButton(
                  label: l.listingEdit,
                  leading: '✏️',
                  style: EcoButtonStyle.ghost,
                  onPressed: () => showListingForm(context, existing: x),
                ),
                EcoButton(
                  label: x.status == ListingStatus.open ? l.listingClose : l.listingReopen,
                  leading: x.status == ListingStatus.open ? '🔒' : '🔓',
                  style: EcoButtonStyle.ghost,
                  loading: state.isLoading,
                  onPressed: () => ctrl.setListingStatus(
                    x.id,
                    x.status == ListingStatus.open ? ListingStatus.closed : ListingStatus.open,
                  ),
                ),
              ],
            )
          else
            EcoCard(child: Text('⛔ ${l.listingModerated}')),
        ],
      ],
    );
  }

  Future<void> _report(BuildContext context, WidgetRef ref, Listing x) async {
    final l = context.l10n;
    var reason = ReportReason.misleading;
    final text = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + MediaQuery.viewInsetsOf(c).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.reportListing, style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in ReportReason.values)
                    EcoChip(
                      label: reasonLabel(l, r),
                      selected: reason == r,
                      onTap: () => set(() => reason = r),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              EcoTextField(label: l.receiveNote, controller: text, maxLength: 500),
              EcoButton(
                label: l.reportSend,
                style: EcoButtonStyle.coral,
                onPressed: () => Navigator.pop(c, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true &&
        await ref.read(marketControllerProvider.notifier).report(x, reason, text.text) &&
        context.mounted) {
      showEcoToast(context, l.reportSent);
    }
    disposeAfterSheet([text]);
  }
}
