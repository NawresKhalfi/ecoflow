import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../admin/domain/admin.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/impact_providers.dart';
import '../../domain/challenge.dart';
import '../widgets/impact_widgets.dart';
import 'challenges_screen.dart';

/// Détail d'un défi (US-121) : objectif collectif, ma contribution,
/// classements individuel et par quartier, récompense.
class ChallengeDetailScreen extends ConsumerStatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});
  final String challengeId;

  @override
  ConsumerState<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends ConsumerState<ChallengeDetailScreen> {
  bool _synced = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(challengeControllerProvider);
    final ctrl = ref.read(challengeControllerProvider.notifier);
    final c = ref.watch(challengeProvider(widget.challengeId)).value;
    final profile = ref.watch(sessionProvider).profile;
    final me = ref.watch(myParticipationProvider(widget.challengeId)).value;
    final people = leaderboard(
      ref.watch(participantsProvider(widget.challengeId)).value ?? const [],
    );
    final claimed = ref.watch(claimedChallengesProvider).contains(widget.challengeId);
    final now = ref.watch(clockProvider)();
    if (c != null && me != null && !_synced) {
      _synced = true;
      ctrl.syncActive([c]);
    }
    final citizen = profile?.role == UserRole.citizen;
    final rank = me == null ? null : people.indexWhere((p) => p.uid == me.uid) + 1;
    return LayeredPage(
      header: HeroHeader(
        title: c?.title ?? l.challengesTitle,
        subtitle: c == null ? null : '📍 ${zoneLabel(l, ref, c.zoneId)}',
        emoji: '🏆',
        gradient: EcoGradients.violet,
        leading: const HeroBack(to: Routes.challenges),
      ),
      children: [
        if (c == null) const Center(child: CircularProgressIndicator()),
        if (c != null) ...[
          ChallengeCard(challenge: c, now: now),
          if (c.description.isNotEmpty) EcoCard(child: Text(c.description)),
          if (citizen)
            EcoCard(
              gradient: me == null ? null : EcoGradients.green,
              decorated: me != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: me == null
                    ? [
                        Text(
                          '🙋 ${l.challengeJoinTitle}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(l.challengeJoinBody),
                        const SizedBox(height: 12),
                        if (canJoin(c, now, joined: false))
                          EcoButton(
                            label: l.challengeJoin,
                            leading: '🏁',
                            loading: state.isLoading,
                            onPressed: () async {
                              if (await ctrl.join(c) && context.mounted) {
                                showEcoToast(context, '🎉 ${l.challengeWelcome}');
                              }
                            },
                          )
                        else
                          EcoChip(label: l.challengeClosed, tone: ChipTone.sun),
                      ]
                    : [
                        Text(
                          l.challengeMine,
                          style: AppTheme.weighted(
                            16,
                            700,
                            color: Colors.white.withValues(alpha: .92),
                          ),
                        ),
                        Text(
                          l.kg(fmtKg(context, me.kg)),
                          style: AppTheme.weighted(34, 800, color: Colors.white),
                        ),
                        if (rank != null && rank > 0)
                          Text(
                            l.challengeRank(rank, people.length),
                            style: AppTheme.weighted(15, 600, color: Colors.white),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          l.challengeHowItCounts,
                          style: AppTheme.weighted(
                            13,
                            500,
                            color: Colors.white.withValues(alpha: .9),
                          ),
                        ),
                        if (canClaim(c, me, now, claimed: claimed)) ...[
                          const SizedBox(height: 12),
                          EcoButton(
                            label: l.challengeClaim(c.rewardPoints),
                            leading: '🏅',
                            loading: state.isLoading,
                            onPressed: () async {
                              if (await ctrl.claim(c) && context.mounted) {
                                showEcoToast(context, '🏅 ${l.challengeClaimed(c.rewardPoints)}');
                              }
                            },
                          ),
                        ],
                        if (claimed) ...[
                          const SizedBox(height: 10),
                          EcoChip(label: '🏅 ${l.challengeRewardReceived}', tone: ChipTone.sun),
                        ],
                      ],
              ),
            ),
          SectionTitle('🥇 ${l.challengeLeaderboard}'),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: people.isEmpty
                ? Padding(padding: const EdgeInsets.all(12), child: Text(l.challengeNobody))
                : Column(
                    children: [
                      for (final (i, p) in people.take(10).indexed)
                        EcoListTile(
                          leading: EcoAvatar(
                            text: switch (i) {
                              0 => '🥇',
                              1 => '🥈',
                              2 => '🥉',
                              _ => '${i + 1}',
                            },
                            gradient: p.uid == me?.uid ? EcoGradients.green : null,
                          ),
                          title: p.uid == me?.uid ? '${p.name} · ${l.challengeYou}' : p.name,
                          subtitle: p.zoneId == null ? null : zoneLabel(l, ref, p.zoneId),
                          trailing: Text(
                            l.kg(fmtKg(context, p.kg)),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          showDivider: i < people.take(10).length - 1,
                        ),
                    ],
                  ),
          ),
          if (c.zoneId == null && zoneRanking(people).length > 1) ...[
            SectionTitle('🏘️ ${l.challengeZones}'),
            EcoCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Column(
                children: [
                  for (final (i, z) in zoneRanking(people).indexed)
                    EcoListTile(
                      leading: EcoAvatar(text: '${i + 1}'),
                      title: z.zoneId == null ? l.challengeNoZone : zoneLabel(l, ref, z.zoneId),
                      subtitle: l.challengeMembers(z.members),
                      trailing: Text(
                        l.kg(fmtKg(context, z.kg)),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      showDivider: i < zoneRanking(people).length - 1,
                    ),
                ],
              ),
            ),
          ],
          if (profile?.can(AdminPermission.broadcast) ?? false)
            EcoLink(
              label: l.challengeDelete,
              color: const Color(0xFFC4482A),
              onPressed: () async {
                if (await ctrl.delete(c) && context.mounted) context.go(Routes.challenges);
              },
            ),
        ],
      ],
    );
  }
}
