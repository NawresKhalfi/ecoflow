import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/wallet_providers.dart';
import '../../data/wallet_repository.dart';
import '../../domain/gamification.dart';
import '../../domain/points_rules.dart';
import '../../domain/wallet.dart';
import 'wallet_labels.dart';

/// Solde, points en attente et gel (US-070, US-075).
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final white = Colors.white.withValues(alpha: .92);
    return EcoCard(
      gradient: EcoGradients.violet,
      decorated: true,
      semanticLabel: l.walletBalanceSemantics(wallet.balance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.walletBalance, style: AppTheme.weighted(15, 600, color: white)),
          Text(
            fmtPoints(context, wallet.balance),
            style: AppTheme.weighted(44, 800, color: Colors.white),
          ),
          Text('EcoPoints', style: AppTheme.weighted(15, 600, color: white)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EcoChip(label: '⬆️ ${l.walletEarned(wallet.earned)}', tone: ChipTone.sun),
              EcoChip(label: '🎁 ${l.walletSpent(wallet.spent)}', tone: ChipTone.sky),
              if (wallet.held > 0)
                EcoChip(label: '⏳ ${l.walletHeld(wallet.held)}', tone: ChipTone.coral),
            ],
          ),
        ],
      ),
    );
  }
}

class FrozenBanner extends StatelessWidget {
  const FrozenBanner({super.key, required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EcoCard(
      gradient: EcoGradients.coral,
      child: Text(
        '🧊 ${l.walletFrozen}${wallet.frozenReason == null ? '' : ' — ${wallet.frozenReason}'}',
        style: AppTheme.weighted(15, 700, color: Colors.white),
      ),
    );
  }
}

/// Niveau et progression (US-076).
class LevelCard extends StatelessWidget {
  const LevelCard({super.key, required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final level = levelFor(wallet.earned);
    final p = levelProgress(wallet.earned);
    return EcoCard(
      child: Row(
        children: [
          EcoAvatar(text: level.emoji, gradient: EcoGradients.green, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.levelTitle(levelLabel(l, level)),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: p.progress,
                    minHeight: 10,
                    semanticsLabel: l.levelTitle(levelLabel(l, level)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.next == null
                      ? l.levelMax
                      : l.levelNext(p.next!.minPoints - wallet.earned, levelLabel(l, p.next!)),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BadgesCard extends StatelessWidget {
  const BadgesCard({super.key, required this.earned});
  final Set<EcoBadge> earned;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eco = context.eco;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '🏅 ${l.badgesTitle(earned.length, EcoBadge.values.length)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final b in EcoBadge.values)
                Semantics(
                  label:
                      '${badgeLabel(l, b)} · ${earned.contains(b) ? l.badgeEarned : l.badgeLocked}',
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: earned.contains(b) ? 1 : .35,
                      child: SizedBox(
                        width: 92,
                        child: Column(
                          children: [
                            Text(b.emoji, style: const TextStyle(fontSize: 30)),
                            Text(
                              badgeLabel(l, b),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: eco.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Politique d'expiration et prochaines échéances (US-078).
class ExpiryCard extends StatelessWidget {
  const ExpiryCard({super.key, required this.wallet, required this.entries, required this.rules});
  final Wallet wallet;
  final List<LedgerEntry> entries;
  final PointsRules rules;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final now = DateTime.now();
    final soon = pointsExpiringSoon(entries, wallet, rules.expiryMonths, now);
    final next = nextExpiry(entries, wallet, rules.expiryMonths);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⌛ ${l.policyTitle}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(l.policyExpiry(rules.expiryMonths)),
          Text(l.policyHeld),
          Text(l.policyFrozen),
          const SizedBox(height: 8),
          if (soon > 0)
            EcoChip(label: l.expiringSoon(soon), tone: ChipTone.coral)
          else if (next != null && wallet.balance > 0)
            EcoChip(label: l.nextExpiry(fmtDate(context, next)), tone: ChipTone.sky),
        ],
      ),
    );
  }
}

/// Code personnel et saisie du code d'un parrain (US-077).
class ReferralCard extends ConsumerStatefulWidget {
  const ReferralCard({super.key, required this.wallet, required this.rules});
  final Wallet wallet;
  final PointsRules rules;

  @override
  ConsumerState<ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends ConsumerState<ReferralCard> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final w = widget.wallet;
    final state = ref.watch(walletControllerProvider);
    final ctrl = ref.read(walletControllerProvider.notifier);
    final canBeReferred = w.referredBy == null && w.collections == 0;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🤝 ${l.referralTitle}', style: Theme.of(context).textTheme.titleMedium),
          Text(
            l.referralBody(widget.rules.referralBonus),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (w.referralCode != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    w.referralCode!,
                    style: AppTheme.weighted(26, 800, color: EcoColors.violetDeep),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: l.referralCopy,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: w.referralCode!));
                    if (context.mounted) showEcoToast(context, l.referralCopied);
                  },
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            )
          else
            EcoButton(
              label: l.referralGetCode,
              leading: '🔗',
              style: EcoButtonStyle.ghost,
              loading: state.isLoading,
              onPressed: ctrl.loadReferralCode,
            ),
          if (canBeReferred) ...[
            const SizedBox(height: 12),
            EcoTextField(label: l.referralEnter, controller: _code, emoji: '🎟️'),
            const SizedBox(height: 8),
            EcoButton(
              label: l.referralApply,
              style: EcoButtonStyle.green,
              loading: state.isLoading,
              onPressed: () async {
                final ok = await ctrl.applyReferral(_code.text);
                if (!context.mounted) return;
                final err = ref.read(walletControllerProvider).error;
                showEcoToast(
                  context,
                  ok
                      ? l.referralApplied
                      : err is ReferralNotAllowed
                      ? l.referralNotAllowed
                      : l.referralUnknown,
                );
              },
            ),
          ] else if (w.referredBy != null) ...[
            const SizedBox(height: 8),
            EcoChip(label: '✅ ${l.referralLinked}'),
          ],
        ],
      ),
    );
  }
}

/// Historique des gains et dépenses (US-070).
class HistoryCard extends ConsumerWidget {
  const HistoryCard({super.key, required this.entries});
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final now = ref.watch(clockProvider)();
    if (entries.isEmpty) return EcoCard(child: Text(l.walletEmpty));
    return EcoCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(
        children: [
          for (final (i, e) in entries.indexed)
            EcoListTile(
              leading: EcoAvatar(text: entryEmoji(e)),
              title: entryTitle(l, e),
              subtitle: [
                fmtDate(context, e.at ?? now),
                if (e.kg > 0) l.kg(fmtKg(context, e.kg)),
                if (e.status == EntryStatus.held) '⏳ ${l.entryHeld}',
                if (e.status == EntryStatus.rejected) '⛔ ${l.entryRejected}',
              ].join(' · '),
              trailing: Text(
                '${e.points > 0 ? '+' : ''}${fmtPoints(context, e.points)}',
                style: AppTheme.weighted(
                  17,
                  800,
                  color: e.status != EntryStatus.credited
                      ? context.eco.muted
                      : e.points >= 0
                      ? EcoColors.primary
                      : const Color(0xFFC4482A),
                ),
              ),
              showDivider: i < entries.length - 1,
            ),
        ],
      ),
    );
  }
}
