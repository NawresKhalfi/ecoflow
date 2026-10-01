import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../admin/domain/admin.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
import '../../../collection/application/collection_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/impact_providers.dart';
import '../../domain/challenge.dart';
import '../widgets/impact_widgets.dart';

/// Nom d'une zone desservie ; « National » sans zone.
String zoneLabel(AppLocalizations l, WidgetRef ref, String? zoneId) {
  if (zoneId == null) return l.challengeNational;
  final zones = ref.watch(collectionConfigProvider).value?.zones ?? const [];
  return zones.where((z) => z.id == zoneId).firstOrNull?.name ?? zoneId;
}

/// Défis communautaires (US-121) : en cours, à venir, terminés ; création
/// par l'administration.
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(sessionProvider).profile;
    final admin = me?.role == UserRole.admin;
    ref.watch(challengeControllerProvider);
    final now = ref.watch(clockProvider)();
    final all = ref.watch(visibleChallengesProvider);
    final loading = ref.watch(challengesProvider).isLoading;
    List<Challenge> of(ChallengeStatus s) => [
      for (final c in all)
        if (c.status(now) == s) c,
    ];
    final sections = [
      (l.challengesActive, of(ChallengeStatus.active)),
      (l.challengesUpcoming, of(ChallengeStatus.upcoming)),
      (l.challengesEnded, of(ChallengeStatus.ended)),
    ];
    return LayeredPage(
      header: HeroHeader(
        title: l.challengesTitle,
        subtitle: l.challengesSubtitle,
        emoji: '🏆',
        gradient: EcoGradients.violet,
        leading: HeroBack(to: admin ? Routes.supervision : Routes.impact),
      ),
      children: [
        if (admin && (me?.can(AdminPermission.broadcast) ?? false))
          EcoButton(
            label: l.challengeCreate,
            leading: '＋',
            style: EcoButtonStyle.green,
            onPressed: () => _create(context, ref),
          ),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (!loading && all.isEmpty) EcoCard(child: Text('🌱 ${l.challengesEmpty}')),
        for (final (title, list) in sections)
          if (list.isNotEmpty) ...[
            SectionTitle(title),
            for (final c in list) ChallengeCard(challenge: c, now: now),
          ],
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final title = TextEditingController();
    final body = TextEditingController();
    final goal = TextEditingController(text: '500');
    final reward = TextEditingController(text: '50');
    String? zone;
    var days = 30;
    final zones = ref.read(collectionConfigProvider).value?.zones ?? const [];
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + MediaQuery.viewInsetsOf(c).bottom),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.challengeCreate, style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 10),
                EcoTextField(
                  label: l.challengeName,
                  controller: title,
                  maxLength: maxChallengeTitle,
                ),
                EcoTextField(
                  label: l.challengeDescription,
                  controller: body,
                  maxLength: maxChallengeBody,
                ),
                Row(
                  children: [
                    Expanded(
                      child: EcoTextField(
                        label: l.challengeGoal,
                        controller: goal,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: EcoTextField(
                        label: l.challengeReward,
                        controller: reward,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: zone,
                  decoration: InputDecoration(labelText: l.challengeZone),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.challengeNational)),
                    for (final z in zones) DropdownMenuItem(value: z.id, child: Text(z.name)),
                  ],
                  onChanged: (v) => set(() => zone = v),
                ),
                const SizedBox(height: 12),
                Text(l.challengeDuration, style: Theme.of(c).textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in const [7, 14, 30, 60])
                      EcoChip(
                        label: l.challengeDays(d),
                        selected: days == d,
                        onTap: () => set(() => days = d),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                EcoButton(
                  label: l.challengePublish,
                  leading: '🏆',
                  style: EcoButtonStyle.green,
                  onPressed: () async {
                    final now = ref.read(clockProvider)();
                    final draft = Challenge(
                      id: '',
                      title: title.text.trim(),
                      description: body.text.trim(),
                      zoneId: zone,
                      goalKg: double.tryParse(goal.text.replaceAll(',', '.').trim()) ?? 0,
                      rewardPoints: int.tryParse(reward.text.trim()) ?? -1,
                      startAt: now,
                      endAt: now.add(Duration(days: days)),
                    );
                    final ok = await ref.read(challengeControllerProvider.notifier).create(draft);
                    if (!c.mounted) return;
                    if (ok) {
                      Navigator.pop(c);
                    } else {
                      showEcoToast(c, l.challengeInvalid);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    disposeAfterSheet([title, body, goal, reward]);
  }
}

/// Résumé d'un défi : objectif collectif, échéance, récompense.
class ChallengeCard extends ConsumerWidget {
  const ChallengeCard({super.key, required this.challenge, required this.now});
  final Challenge challenge;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final c = challenge;
    final status = c.status(now);
    final joined = ref.watch(myParticipationProvider(c.id)).value != null;
    return EcoCard(
      onTap: () => context.go(Routes.challenge(c.id)),
      semanticLabel: c.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const EcoAvatar(text: '🏆', gradient: EcoGradients.violet),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '📍 ${zoneLabel(l, ref, c.zoneId)} · ${l.challengeMembers(c.participants)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressPill(value: c.progress, color: c.achieved ? EcoColors.primary : EcoColors.violet),
          const SizedBox(height: 6),
          Text(
            l.challengeProgress(fmtKg(context, c.totalKg), fmtKg(context, c.goalKg)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              EcoChip(
                label: switch (status) {
                  ChallengeStatus.active => '⏳ ${l.challengeDaysLeft(c.daysLeft(now))}',
                  ChallengeStatus.upcoming =>
                    '🗓️ ${l.challengeStarts(fmtDate(context, c.startAt))}',
                  ChallengeStatus.ended =>
                    c.achieved ? '🎉 ${l.challengeAchieved}' : l.challengeMissed,
                },
                tone: switch (status) {
                  ChallengeStatus.active => ChipTone.sky,
                  ChallengeStatus.upcoming => ChipTone.sun,
                  ChallengeStatus.ended => c.achieved ? ChipTone.green : ChipTone.coral,
                },
              ),
              if (c.rewardPoints > 0)
                EcoChip(
                  label: '🏅 ${l.challengeRewardChip(c.rewardPoints)}',
                  tone: ChipTone.violet,
                ),
              if (joined) EcoChip(label: '✅ ${l.challengeJoined}'),
            ],
          ),
        ],
      ),
    );
  }
}
