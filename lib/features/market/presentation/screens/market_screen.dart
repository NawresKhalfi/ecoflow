import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/domain/company_profile.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../recycler/presentation/widgets/recycler_labels.dart';
import '../../application/market_providers.dart';
import '../../domain/market.dart';
import '../widgets/listing_form.dart';
import '../widgets/market_widgets.dart';

enum _Tab { browse, forYou, mine, deals }

/// Marketplace B2B : annonces, suggestions, mes annonces, négociations
/// (US-094 à US-098, US-102).
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  _Tab _tab = _Tab.browse;
  final _city = TextEditingController();
  final _query = TextEditingController();

  @override
  void dispose() {
    _city.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    final uid = ref.watch(currentUidProvider);
    final f = ref.watch(listingFilterProvider);
    final setF = ref.read(listingFilterProvider.notifier).set;
    final all = ref.watch(openListingsProvider).value ?? const <Listing>[];
    final shown = all.where((x) => x.ownerUid != uid && f.matches(x, now)).toList();
    final suggestions = ref.watch(suggestionsProvider);
    final mine = ref.watch(myListingsProvider).value ?? const <Listing>[];
    final deals = ref.watch(myDealsProvider).value ?? const <Deal>[];
    final orders = ref.watch(myOrdersProvider).value ?? const <MarketOrder>[];
    final active = orders
        .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
        .length;

    Widget card(Listing x, {String? extra}) =>
        ListingCard(listing: x, extra: extra, onTap: () => context.go(Routes.listing(x.id)));

    return LayeredPage(
      header: HeroHeader(
        title: l.marketTitle,
        subtitle: l.marketSubtitle,
        emoji: '🤝',
        gradient: EcoGradients.green,
      ),
      children: [
        ResponsiveGrid(
          children: [
            EcoButton(
              label: l.listingNew,
              leading: '📢',
              onPressed: () async {
                final ok = await showListingForm(context);
                if (ok == true && context.mounted) showEcoToast(context, l.listingPublished);
              },
            ),
            EcoButton(
              label: active > 0 ? '${l.ordersTitle} ($active)' : l.ordersTitle,
              leading: '📦',
              style: EcoButtonStyle.ghost,
              onPressed: () => context.go(Routes.orders),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (t, label) in [
              (_Tab.browse, l.marketBrowse),
              (_Tab.forYou, '${l.marketForYou} (${suggestions.length})'),
              (_Tab.mine, l.marketMine),
              (_Tab.deals, '${l.marketDeals} (${deals.length})'),
            ])
              EcoChip(
                label: label,
                tone: ChipTone.violet,
                selected: _tab == t,
                onTap: () => setState(() => _tab = t),
              ),
          ],
        ),
        if (_tab == _Tab.browse) ...[
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    EcoChip(
                      label: l.rewardsAll,
                      selected: f.type == null,
                      onTap: () => setF(f.copyWith(type: () => null)),
                    ),
                    EcoChip(
                      label: '🔎 ${l.listingBuy}',
                      selected: f.type == ListingType.buy,
                      onTap: () => setF(f.copyWith(type: () => ListingType.buy)),
                    ),
                    EcoChip(
                      label: '🏷️ ${l.listingSell}',
                      selected: f.type == ListingType.sell,
                      onTap: () => setF(f.copyWith(type: () => ListingType.sell)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<RecyclableMaterial?>(
                  initialValue: f.material,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.reportMaterial),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.dashAllMaterials)),
                    for (final m in RecyclableMaterial.values)
                      DropdownMenuItem(
                        value: m,
                        child: Text('${materialEmoji(m)} ${materialLabel(l, m)}'),
                      ),
                  ],
                  onChanged: (v) => setF(f.copyWith(material: () => v)),
                ),
                const SizedBox(height: 10),
                EcoTextField(
                  label: l.listingCity,
                  controller: _city,
                  emoji: '📍',
                  onChanged: (v) => setF(f.copyWith(city: v)),
                ),
                const SizedBox(height: 10),
                EcoTextField(
                  label: l.marketSearch,
                  controller: _query,
                  emoji: '🔎',
                  onChanged: (v) => setF(f.copyWith(query: v)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final kg in [null, 100.0, 500.0, 1000.0])
                      EcoChip(
                        tone: ChipTone.sky,
                        label: kg == null ? l.marketAnyQty : l.marketMinKg(kg.round()),
                        selected: f.minKg == kg,
                        onTap: () => setF(f.copyWith(minKg: () => kg)),
                      ),
                    for (final d in [null, 7, 30])
                      EcoChip(
                        tone: ChipTone.sun,
                        label: d == null ? l.marketAnyDate : l.marketWithinDays(d),
                        selected: d == null
                            ? f.before == null
                            : f.before?.difference(now).inDays == d,
                        onTap: () => setF(
                          f.copyWith(before: () => d == null ? null : now.add(Duration(days: d))),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Text(l.marketResults(shown.length), style: Theme.of(context).textTheme.bodySmall),
          if (shown.isEmpty) EcoCard(child: Text(l.marketEmpty)),
          ResponsiveGrid(children: [for (final x in shown) card(x)]),
        ],
        if (_tab == _Tab.forYou) ...[
          EcoCard(child: Text('💡 ${l.marketForYouHelp}')),
          if (suggestions.isEmpty) EcoCard(child: Text(l.marketEmpty)),
          ResponsiveGrid(
            children: [
              for (final s in suggestions)
                card(
                  s.listing,
                  extra: s.listing.type == ListingType.buy
                      ? l.suggestFromStock(l.kg(fmtKg(context, s.matchKg)))
                      : l.suggestMatchesNeed,
                ),
            ],
          ),
        ],
        if (_tab == _Tab.mine) ...[
          if (mine.isEmpty) EcoCard(child: Text(l.marketMineEmpty)),
          ResponsiveGrid(children: [for (final x in mine) card(x)]),
        ],
        if (_tab == _Tab.deals)
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: deals.isEmpty
                ? Padding(padding: const EdgeInsets.all(8), child: Text(l.marketDealsEmpty))
                : Column(
                    children: [
                      for (final (i, d) in deals.indexed)
                        EcoListTile(
                          leading: EcoAvatar(
                            text: d.otherName(uid ?? '').isEmpty ? '?' : d.otherName(uid ?? '')[0],
                          ),
                          title: '${d.otherName(uid ?? '')} · ${d.listingTitle}',
                          subtitle: d.lastMessage.isEmpty ? l.chatEmpty : d.lastMessage,
                          onTap: () => context.go(Routes.deal(d.id)),
                          showDivider: i < deals.length - 1,
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}
