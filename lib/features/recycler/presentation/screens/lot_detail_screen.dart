import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../application/recycler_providers.dart';
import '../../domain/stock.dart';
import '../widgets/recycler_labels.dart';
import '../widgets/stock_sheets.dart';

/// Fiche d'un lot et sa traçabilité jusqu'aux collectes (US-084).
class LotDetailScreen extends ConsumerWidget {
  const LotDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lots = ref.watch(myLotsProvider).value ?? const <StockLot>[];
    final lot = lots.where((x) => x.id == id).firstOrNull;
    final moves = (ref.watch(myMovesProvider).value ?? const <StockMove>[])
        .where((m) => m.lotId == id)
        .toList();
    final state = ref.watch(recyclerControllerProvider);
    final back = IconButton.filledTonal(
      tooltip: l.commonBack,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .22),
        foregroundColor: Colors.white,
      ),
      onPressed: () => context.go(Routes.stock),
      icon: const BackButtonIcon(),
    );
    if (lot == null) {
      return LayeredPage(
        header: HeroHeader(title: l.stockLots, leading: back),
        children: const [Center(child: CircularProgressIndicator())],
      );
    }
    final inputs = [for (final i in lot.inputLotIds) ...lots.where((x) => x.id == i)];
    return LayeredPage(
      header: HeroHeader(
        title: lot.reference,
        subtitle: '${materialLabel(l, lot.material)} · ${formLabel(l, lot.form)}',
        emoji: materialEmoji(lot.material),
        gradient: EcoGradients.green,
        leading: back,
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.kg(fmtKg(context, lot.kg)), style: Theme.of(context).textTheme.headlineSmall),
              Text(
                l.lotInitial(l.kg(fmtKg(context, lot.initialKg))),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  EcoChip(label: gradeLabel(l, lot.grade)),
                  EcoChip(label: formLabel(l, lot.form), tone: ChipTone.sky),
                  if (lot.receivedAt != null)
                    EcoChip(label: fmtDate(context, lot.receivedAt!), tone: ChipTone.sun),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: lot.marketplace,
                title: Text(l.lotMarketplace),
                subtitle: Text(l.lotMarketplaceHelp),
                onChanged: state.isLoading
                    ? null
                    : (v) => ref.read(recyclerControllerProvider.notifier).setMarketplace(lot, v),
              ),
              EcoButton(
                label: l.moveOutTitle,
                leading: '📤',
                style: EcoButtonStyle.ghost,
                onPressed: lot.inStock
                    ? () async {
                        final ok = await showMoveOutSheet(context, lot);
                        if (ok == true && context.mounted) showEcoToast(context, l.moveOutDone);
                      }
                    : null,
              ),
            ],
          ),
        ),
        SectionTitle('🔎 ${l.traceTitle}'),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              if (lot.source == LotSource.reception) ...[
                EcoListTile(
                  leading: const EcoAvatar(text: '🚚'),
                  title: lot.collectorName ?? '—',
                  subtitle: l.traceDeposit(lot.depositId ?? '—'),
                ),
                EcoListTile(
                  leading: const EcoAvatar(text: '📍'),
                  title: lot.zoneIds.isEmpty ? '—' : lot.zoneIds.map(zoneLabel).join(', '),
                  subtitle: l.dashZone,
                  showDivider: lot.missions.isNotEmpty,
                ),
                for (final (i, m) in lot.missions.indexed)
                  EcoListTile(
                    leading: const EcoAvatar(text: '♻️'),
                    title: l.traceMission(m.id.length > 6 ? m.id.substring(0, 6) : m.id),
                    subtitle:
                        '${fmtDate(context, m.day)} · ${zoneLabel(m.zoneId)} · ${l.kg(fmtKg(context, m.kg))}',
                    showDivider: i < lot.missions.length - 1,
                  ),
                if (lot.missions.isEmpty)
                  Padding(padding: const EdgeInsets.all(8), child: Text(l.traceNoMissions)),
              ] else ...[
                for (final (i, x) in inputs.indexed)
                  EcoListTile(
                    leading: EcoAvatar(text: materialEmoji(x.material)),
                    title: '${x.reference} · ${x.collectorName ?? '—'}',
                    subtitle: l.traceInput(l.kg(fmtKg(context, x.initialKg))),
                    onTap: () => context.go(Routes.lotDetail(x.id)),
                    showDivider: i < inputs.length - 1,
                  ),
                if (inputs.isEmpty)
                  Padding(padding: const EdgeInsets.all(8), child: Text(l.traceNoMissions)),
              ],
            ],
          ),
        ),
        if (moves.isNotEmpty) ...[
          SectionTitle('🕒 ${l.lotMoves}'),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, m) in moves.indexed)
                  EcoListTile(
                    leading: EcoAvatar(text: m.deltaKg >= 0 ? '⬇️' : '⬆️'),
                    title: moveLabel(l, m.reason),
                    subtitle: [
                      if (m.at != null) fmtDate(context, m.at!),
                      if (m.note.isNotEmpty) m.note,
                    ].join(' · '),
                    trailing: Text(
                      '${m.deltaKg >= 0 ? '+' : '−'}${fmtKg(context, m.deltaKg.abs())}',
                    ),
                    showDivider: i < moves.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
