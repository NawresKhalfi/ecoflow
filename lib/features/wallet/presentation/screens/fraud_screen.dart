import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/wallet_providers.dart';
import '../../domain/wallet.dart';
import '../widgets/wallet_labels.dart';

/// Contrôle anti-fraude (US-075) : points mis en attente par les règles,
/// validation, rejet ou gel du wallet.
class FraudScreen extends ConsumerWidget {
  const FraudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final held = ref.watch(heldEntriesProvider).value ?? const <LedgerEntry>[];
    return LayeredPage(
      header: HeroHeader(
        title: l.fraudTitle,
        subtitle: l.fraudSubtitle,
        emoji: '🛡️',
        gradient: EcoGradients.coral,
      ),
      children: [
        EcoCard(child: Text('ℹ️ ${l.fraudExplain}')),
        if (held.isEmpty) EcoCard(child: Text('✅ ${l.fraudEmpty}')),
        for (final e in held) _HeldCard(entry: e),
      ],
    );
  }
}

class _HeldCard extends ConsumerWidget {
  const _HeldCard({required this.entry});
  final LedgerEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(walletAdminControllerProvider);
    final ctrl = ref.read(walletAdminControllerProvider.notifier);
    Future<void> act(Future<bool> f, String done) async {
      if (await f && context.mounted) showEcoToast(context, done);
    }

    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EcoListTile(
            leading: const EcoAvatar(text: '⏳', gradient: EcoGradients.sun),
            title: l.points(fmtPoints(context, entry.points)),
            subtitle: [
              if (entry.at != null) fmtDate(context, entry.at!),
              l.kg(fmtKg(context, entry.kg)),
              l.fraudCitizen(entry.uid.length > 6 ? entry.uid.substring(0, 6) : entry.uid),
            ].join(' · '),
            showDivider: false,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in entry.flags)
                EcoChip(label: '⚠️ ${flagLabel(l, f)}', tone: ChipTone.coral),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: EcoButton(
                  label: l.fraudApprove,
                  style: EcoButtonStyle.green,
                  loading: state.isLoading,
                  onPressed: () => act(ctrl.review(entry, approve: true), l.fraudApproved),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EcoButton(
                  label: l.fraudReject,
                  style: EcoButtonStyle.ghost,
                  loading: state.isLoading,
                  onPressed: () => act(ctrl.review(entry, approve: false), l.fraudRejected),
                ),
              ),
            ],
          ),
          EcoLink(
            label: '🧊 ${l.fraudFreeze}',
            color: const Color(0xFFC4482A),
            onPressed: () => act(
              ctrl.setFrozen(entry.uid, frozen: true, reason: l.fraudFreezeReason),
              l.fraudFrozen,
            ),
          ),
        ],
      ),
    );
  }
}
