import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../recycler/application/recycler_providers.dart';
import '../../../recycler/presentation/widgets/recycler_labels.dart';
import '../../../scan/application/scan_providers.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../wallet/application/wallet_providers.dart';
import '../../../wallet/domain/gamification.dart';
import '../../../wallet/presentation/widgets/wallet_labels.dart';
import '../../application/impact_providers.dart';
import '../../domain/impact.dart';
import '../widgets/impact_share_card.dart';
import '../widgets/impact_widgets.dart';
import '../widgets/monthly_bars.dart';

/// Mon impact : tableau de bord personnel (US-118), CO₂ évité et
/// équivalences (US-119), carte à partager (US-122).
class ImpactScreen extends ConsumerWidget {
  const ImpactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final impact = ref.watch(personalImpactProvider);
    final firstName = ref.watch(sessionProvider).profile?.firstName ?? '';
    final level = levelFor(ref.watch(myWalletProvider).value?.earned ?? 0);
    return LayeredPage(
      header: HeroHeader(
        title: l.impactTitle,
        subtitle: l.impactSubtitle,
        emoji: '🌍',
        gradient: EcoGradients.green,
        leading: const HeroBack(to: Routes.home),
      ),
      children: [
        if (impact.isEmpty)
          EcoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('🌱 ${l.impactEmptyTitle}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(l.impactEmptyBody),
                const SizedBox(height: 14),
                EcoButton(
                  label: l.homeScanCta,
                  leading: '📸',
                  onPressed: () => context.go(Routes.scan),
                ),
              ],
            ),
          ),
        _Totals(impact: impact),
        _ThisMonth(impact: impact),
        _Co2Card(impact: impact),
        if (!impact.isEmpty)
          EcoButton(
            label: l.shareCta,
            leading: '📣',
            style: EcoButtonStyle.green,
            onPressed: () => _share(context, ref, impact, firstName, level),
          ),
        LinkCard(
          emoji: '💡',
          title: l.tipsTitle,
          subtitle: l.tipsSubtitle,
          onTap: () => context.go(Routes.tips),
        ),
        LinkCard(
          emoji: '🏆',
          title: l.challengesTitle,
          subtitle: l.challengesSubtitle,
          onTap: () => context.go(Routes.challenges),
        ),
        Text(l.co2Method, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    PersonalImpact impact,
    String firstName,
    EcoLevel level,
  ) async {
    final l = context.l10n;
    final key = GlobalKey();
    final text = l.shareText(fmtKg(context, impact.totalKg), fmtKg(context, impact.co2Kg));
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) {
        var busy = false;
        return StatefulBuilder(
          builder: (c, set) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.sharePreview, style: Theme.of(c).textTheme.titleLarge),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * .55),
                  child: Center(
                    child: RepaintBoundary(
                      key: key,
                      child: ImpactShareCard(impact: impact, firstName: firstName, level: level),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                EcoButton(
                  label: l.shareNow,
                  leading: '📤',
                  loading: busy,
                  onPressed: () async {
                    set(() => busy = true);
                    try {
                      final dir = await ref.read(exportDirectoryProvider)();
                      final path = await captureCard(key, dir);
                      await ref.read(imageSharerProvider)(path, text);
                      if (c.mounted) Navigator.pop(c);
                    } catch (_) {
                      if (c.mounted) {
                        set(() => busy = false);
                        showEcoToast(c, l.shareFailed);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.impact});
  final PersonalImpact impact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(emoji: '♻️', value: fmtKg(context, impact.totalKg), label: l.statKg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                emoji: '🚚',
                value: '${impact.collections}',
                label: l.statCollections,
                gradient: EcoGradients.sky,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatTile(
                emoji: '💰',
                value: fmtDt(context, impact.valueDt),
                label: l.impactValue,
                gradient: EcoGradients.sun,
                foreground: EcoColors.onSun,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                emoji: '🏅',
                value: fmtPoints(context, impact.points),
                label: l.impactPointsEarned,
                gradient: EcoGradients.violet,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ThisMonth extends StatelessWidget {
  const _ThisMonth({required this.impact});
  final PersonalImpact impact;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final trend = impact.kgTrend;
    final (label, tone) = switch (trend) {
      null when impact.current.kg > 0 => (l.impactFirstMonth, ChipTone.sky),
      null => (l.impactNoPrevious, ChipTone.sky),
      final t when t >= 0 => (l.impactTrendUp('${(t * 100).round()}'), ChipTone.green),
      final t => (l.impactTrendDown('${(-t * 100).round()}'), ChipTone.coral),
    };
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('📅 ${l.impactThisMonth}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l.kg(fmtKg(context, impact.current.kg)),
                style: AppTheme.weighted(28, 800, color: context.eco.ink),
              ),
              EcoChip(label: label, tone: tone),
            ],
          ),
          Text(
            l.impactMonthDetail(
              impact.current.collections,
              l.dt(fmtDt(context, impact.current.valueDt)),
              fmtKg(context, impact.current.co2Kg),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          MonthlyBars(months: impact.months),
        ],
      ),
    );
  }
}

class _Co2Card extends ConsumerWidget {
  const _Co2Card({required this.impact});
  final PersonalImpact impact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final catalog = ref.watch(catalogProvider).value ?? defaultCatalog;
    final shares = impact.co2ByCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    String name(String id) => catalog.where((c) => c.id == id).firstOrNull?.name(lang) ?? id;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('🌍 ${l.co2Title}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            l.co2Kg(fmtKg(context, impact.co2Kg)),
            style: AppTheme.weighted(30, 800, color: EcoColors.primary),
          ),
          Text(l.co2Subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          _Equivalent(emoji: '🚗', text: l.eqCarKm(fmtWhole(context, impact.carKm))),
          _Equivalent(emoji: '🌳', text: l.eqTrees(fmtKg(context, impact.treeYears))),
          _Equivalent(emoji: '📱', text: l.eqPhone(fmtWhole(context, impact.phoneCharges))),
          if (shares.isNotEmpty) ...[
            const Divider(height: 28),
            Text(l.co2ByMaterial, style: Theme.of(context).textTheme.titleSmall),
            for (final (i, e) in shares.take(5).indexed)
              ShareBar(
                label: name(e.key),
                value: l.co2Kg(fmtKg(context, e.value)),
                fraction: impact.co2Kg == 0 ? 0 : e.value / impact.co2Kg,
                color: categoryColor(i),
              ),
          ],
        ],
      ),
    );
  }
}

class _Equivalent extends StatelessWidget {
  const _Equivalent({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        EcoAvatar(text: emoji, size: 40),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleSmall)),
      ],
    ),
  );
}
