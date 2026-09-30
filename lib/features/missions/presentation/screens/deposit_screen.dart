import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../collection/presentation/widgets/collection_labels.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../application/collector_controllers.dart';
import '../../application/missions_providers.dart';
import '../../data/collector_repositories.dart';
import '../../domain/deposit.dart';
import '../widgets/mission_labels.dart';
import '../../../recycler/application/recycler_providers.dart';
import '../../../recycler/domain/purchasing.dart';
import '../../../recycler/presentation/widgets/recycler_labels.dart';

/// Dépôt de la tournée chez un recycleur (US-055).
class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  Recycler? _recycler;
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final recyclers = ref.watch(approvedRecyclersProvider).value ?? const [];
    // Conditions d'achat annoncées (US-085) pour orienter la livraison.
    final offers = {
      for (final o in ref.watch(recyclerOffersProvider).value ?? const <RecyclerOffer>[])
        o.uid: o.purchasing,
    };
    final ctrl = ref.read(depositControllerProvider.notifier);
    final state = ref.watch(depositControllerProvider);
    final candidates = ctrl.depositable(ref.watch(myMissionsProvider).value ?? const []);
    final deposits = ref.watch(myDepositsProvider).value ?? const [];
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    return LayeredPage(
      header: HeroHeader(
        title: l.depositTitle,
        subtitle: l.depositSubtitle,
        emoji: '🏭',
        gradient: EcoGradients.sky,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.earnings),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.depositRecycler, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (recyclers.isEmpty) Text(l.depositNoRecycler),
              RadioGroup<String>(
                groupValue: _recycler?.uid,
                onChanged: (uid) =>
                    setState(() => _recycler = recyclers.where((r) => r.uid == uid).firstOrNull),
                child: Column(
                  children: [
                    for (final r in recyclers)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: r.uid,
                        title: Text('🏭 ${r.name} · ${r.city}'),
                        subtitle: Text(offerSummary(l, context, offers[r.uid])),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.depositMissions, style: Theme.of(context).textTheme.titleMedium),
              if (candidates.isEmpty) Text(l.depositNothing),
              for (final m in candidates)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(m.id),
                  onChanged: (v) =>
                      setState(() => v == true ? _selected.add(m.id) : _selected.remove(m.id)),
                  title: Text(m.place.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${slotLabel(context, m.slot)} · ${statusLabel(l, m.status)}'),
                ),
              const SizedBox(height: 10),
              EcoButton(
                label: l.depositSend,
                leading: '📦',
                style: EcoButtonStyle.green,
                loading: state.isLoading,
                onPressed: _recycler == null || _selected.isEmpty
                    ? null
                    : () async {
                        final ok = await ctrl.deposit(
                          _recycler!,
                          candidates.where((m) => _selected.contains(m.id)).toList(),
                        );
                        if (ok && context.mounted) {
                          showEcoToast(context, l.depositSent);
                          setState(_selected.clear);
                        }
                      },
              ),
            ],
          ),
        ),
        if (deposits.isNotEmpty) ...[
          SectionTitle(l.depositMine),
          for (final d in deposits)
            EcoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '🏭 ${d.recyclerName}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      EcoChip(
                        label: depositLabel(l, d.status),
                        tone: d.status == DepositStatus.confirmed
                            ? ChipTone.green
                            : (d.status == DepositStatus.rejected ? ChipTone.coral : ChipTone.sun),
                      ),
                    ],
                  ),
                  Text('${l.kg(fmtKg(context, d.totalKg))} · ${d.missionIds.length} ×'),
                  Text(
                    d.byCategoryKg.entries
                        .map(
                          (e) =>
                              '${categoryById(catalog, e.key).emoji} ${l.kg(fmtKg(context, e.value))}',
                        )
                        .join('  '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
