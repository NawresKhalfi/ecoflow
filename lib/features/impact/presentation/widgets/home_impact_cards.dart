import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../application/impact_providers.dart';
import '../../domain/challenge.dart';
import 'impact_widgets.dart';

/// Accès citoyen depuis l'accueil : impact, conseils de tri, défis.
class HomeImpactCards extends ConsumerWidget {
  const HomeImpactCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final impact = ref.watch(personalImpactProvider);
    final now = ref.watch(clockProvider)();
    final active = ref
        .watch(visibleChallengesProvider)
        .where((c) => c.status(now) == ChallengeStatus.active)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinkCard(
          emoji: '🌍',
          title: l.impactTitle,
          subtitle: impact.isEmpty
              ? l.impactHomeEmpty
              : l.impactHomeSummary(fmtKg(context, impact.co2Kg)),
          gradient: EcoGradients.green,
          onTap: () => context.go(Routes.impact),
        ),
        const SizedBox(height: 12),
        ResponsiveGrid(
          minItemWidth: 160,
          spacing: 12,
          children: [
            LinkCard(
              emoji: '💡',
              title: l.tipsShort,
              subtitle: l.tipsHome,
              onTap: () => context.go(Routes.tips),
            ),
            LinkCard(
              emoji: '🏆',
              title: l.challengesShort,
              subtitle: active == 0 ? l.challengesHomeNone : l.challengesHomeActive(active),
              onTap: () => context.go(Routes.challenges),
            ),
          ],
        ),
      ],
    );
  }
}
