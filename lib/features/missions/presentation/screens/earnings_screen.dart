import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/collector_controllers.dart';
import '../../application/missions_providers.dart';
import '../../domain/earnings.dart';
import '../widgets/earnings_chart.dart';
import '../widgets/mission_labels.dart';

/// Historique des revenus, période, solde et retraits (US-051, US-052).
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});

  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  EarningsPeriod _period = EarningsPeriod.week;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    final earnings = ref.watch(earningsProvider).value ?? const [];
    final payouts = ref.watch(payoutsProvider).value ?? const [];
    final totals = periodTotals(earnings, _period, now);
    final balance = availableBalance(earnings, payouts);
    return LayeredPage(
      header: HeroHeader(
        title: l.earningsTitle,
        subtitle: l.earningsSubtitle,
        emoji: '💰',
        gradient: EcoGradients.sun,
      ),
      children: [
        EcoCard(
          child: Wrap(
            spacing: 8,
            children: [
              for (final p in EarningsPeriod.values)
                EcoChip(
                  label: periodLabel(l, p),
                  selected: p == _period,
                  onTap: () => setState(() => _period = p),
                ),
            ],
          ),
        ),
        EcoCard(
          gradient: EcoGradients.sun,
          decorated: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.earningsTotal, style: AppTheme.weighted(14, 700, color: EcoColors.onSun)),
              Text(
                l.dt(fmtDt(context, totals.dt)),
                style: AppTheme.weighted(40, 800, color: EcoColors.onSun),
              ),
              Text(
                '${l.kg(fmtKg(context, totals.kg))} · ${l.earningsMissions(totals.missions)}',
                style: AppTheme.weighted(15, 600, color: EcoColors.onSun),
              ),
            ],
          ),
        ),
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.earningsChart, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              EarningsBars(values: lastSevenDays(earnings, now), lastDay: now),
            ],
          ),
        ),
        EcoCard(
          gradient: EcoGradients.green,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.earningsBalance, style: AppTheme.weighted(14, 700, color: Colors.white)),
              Text(
                l.dt(fmtDt(context, balance)),
                style: AppTheme.weighted(30, 800, color: Colors.white),
              ),
              const SizedBox(height: 10),
              EcoButton(
                label: l.earningsWithdraw,
                leading: '🏦',
                style: EcoButtonStyle.ghost,
                onPressed: balance >= minWithdrawalDt ? () => _withdraw(context, balance) : null,
              ),
            ],
          ),
        ),
        EcoButton(
          label: l.depositTitle,
          leading: '🏭',
          style: EcoButtonStyle.ghost,
          onPressed: () => context.go(Routes.deposit),
        ),
        if (payouts.isNotEmpty)
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, p) in payouts.indexed)
                  EcoListTile(
                    leading: const EcoAvatar(text: '🏦'),
                    title: l.dt(fmtDt(context, p.amountDt)),
                    subtitle: [
                      methodLabel2(l, p.method),
                      if (p.requestedAt != null) fmtDate(context, p.requestedAt!),
                    ].join(' · '),
                    showDivider: i < payouts.length - 1,
                    trailing: EcoChip(
                      label: payoutLabel(l, p.status),
                      tone: switch (p.status) {
                        PayoutStatus.paid => ChipTone.green,
                        PayoutStatus.rejected => ChipTone.coral,
                        _ => ChipTone.sun,
                      },
                    ),
                  ),
              ],
            ),
          ),
        SectionTitle(l.earningsHistory),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: earnings.isEmpty
              ? Padding(padding: const EdgeInsets.all(12), child: Text(l.earningsEmpty))
              : Column(
                  children: [
                    for (final (i, e) in earnings.indexed)
                      EcoListTile(
                        leading: const EcoAvatar(text: '♻️'),
                        title: '+${l.dt(fmtDt(context, e.amountDt))}',
                        subtitle: '${fmtDate(context, e.at)} · ${l.kg(fmtKg(context, e.kg))}',
                        showDivider: i < earnings.length - 1,
                        onTap: () => context.go(Routes.missionDetail(e.missionId)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _withdraw(BuildContext context, double balance) async {
    final l = context.l10n;
    final amount = TextEditingController(text: balance.toStringAsFixed(3));
    var method = PayoutMethod.bankTransfer;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.earningsWithdraw, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.withdrawAmount,
                  helperText: l.withdrawInvalid,
                ),
              ),
              const SizedBox(height: 12),
              Text(l.withdrawMethod, style: Theme.of(ctx).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in PayoutMethod.values)
                    EcoChip(
                      label: methodLabel2(l, m),
                      selected: m == method,
                      onTap: () => setSheet(() => method = m),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              EcoButton(
                label: l.withdrawSend,
                style: EcoButtonStyle.green,
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      final value = parseKg(amount.text) ?? 0;
      final sent = await ref.read(earningsControllerProvider.notifier).withdraw(value, method);
      if (context.mounted) showEcoToast(context, sent ? l.withdrawSent : l.withdrawInvalid);
    }
    amount.dispose();
  }
}
