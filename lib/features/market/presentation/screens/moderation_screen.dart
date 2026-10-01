import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/market_providers.dart';
import '../../data/market_repository.dart';
import '../../domain/market.dart';
import '../widgets/market_widgets.dart';

/// Modération des annonces et des signalements (US-103).
class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  ListingStatus? _status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final reports = ref.watch(reportsProvider).value ?? const <ListingReport>[];
    final listings = ref.watch(allListingsProvider).value ?? const <Listing>[];
    final byId = {for (final x in listings) x.id: x};
    final ctrl = ref.read(marketControllerProvider.notifier);
    ref.watch(marketControllerProvider);
    final shown = listings.where((x) => _status == null || x.status == _status).toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(3000)).compareTo(a.createdAt ?? DateTime(3000)));

    List<Widget> actions(Listing x) => [
      if (x.status != ListingStatus.suspended)
        TextButton(
          onPressed: () => ctrl.setListingStatus(x.id, ListingStatus.suspended),
          child: Text(l.modSuspend),
        ),
      if (x.status != ListingStatus.removed)
        TextButton(
          onPressed: () => ctrl.setListingStatus(x.id, ListingStatus.removed),
          child: Text(l.modRemove),
        ),
      if (x.status == ListingStatus.suspended || x.status == ListingStatus.removed)
        TextButton(
          onPressed: () => ctrl.setListingStatus(x.id, ListingStatus.open),
          child: Text(l.modRestore),
        ),
    ];

    return LayeredPage(
      header: HeroHeader(
        title: l.modTitle,
        subtitle: l.modSubtitle,
        emoji: '🧹',
        gradient: EcoGradients.coral,
      ),
      children: [
        SectionTitle('🚩 ${l.modReports(reports.length)}'),
        if (reports.isEmpty) EcoCard(child: Text('✅ ${l.modNoReport}')),
        for (final r in reports)
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '🚩 ${reasonLabel(l, r.reason)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (r.text.isNotEmpty) Text(r.text),
                if (r.at != null)
                  Text(fmtDate(context, r.at!), style: Theme.of(context).textTheme.bodySmall),
                if (byId[r.listingId] case final x?) ...[
                  const SizedBox(height: 8),
                  ListingCard(listing: x),
                  Wrap(children: actions(x)),
                ],
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FilledButton.tonal(
                    onPressed: () => ctrl.resolveReport(r.id),
                    child: Text(l.modResolve),
                  ),
                ),
              ],
            ),
          ),
        SectionTitle('📋 ${l.modListings}'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            EcoChip(
              label: l.rewardsAll,
              selected: _status == null,
              onTap: () => setState(() => _status = null),
            ),
            for (final s in ListingStatus.values)
              EcoChip(
                label: listingStatusLabel(l, s),
                selected: _status == s,
                onTap: () => setState(() => _status = s),
              ),
          ],
        ),
        for (final x in shown) ...[ListingCard(listing: x), Wrap(children: actions(x))],
      ],
    );
  }
}
