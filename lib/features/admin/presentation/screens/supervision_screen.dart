import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../profile/presentation/screens/company_screen.dart';
import '../../../recycler/domain/analytics.dart';
import '../../../recycler/presentation/widgets/recycler_labels.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../application/admin_providers.dart';
import '../../data/platform_report.dart';
import '../../domain/admin.dart';
import '../../domain/platform_stats.dart';

/// Tableau de bord de supervision (US-109 à US-111, US-115) et accès aux
/// outils d'administration.
class SupervisionScreen extends ConsumerWidget {
  const SupervisionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final me = ref.watch(sessionProvider).profile;
    final period = ref.watch(statsPeriodProvider);
    final stats = ref.watch(platformStatsProvider);
    final loading = ref.watch(statsDataProvider).isLoading;
    final pending = ref.watch(pendingReviewsProvider).value?.length ?? 0;
    final disputes = (ref.watch(disputesProvider).value ?? const <Dispute>[])
        .where((d) => d.status == DisputeStatus.open)
        .length;
    final state = ref.watch(adminControllerProvider);
    bool can(String p) => me?.can(p) ?? false;

    Widget tool(String emoji, String title, String subtitle, String route, {int badge = 0, bool show = true}) =>
        show
        ? EcoListTile(
            leading: EcoAvatar(text: emoji),
            title: title,
            subtitle: subtitle,
            trailing: badge > 0 ? EcoChip(label: '$badge', tone: ChipTone.coral) : null,
            onTap: () => context.go(route),
          )
        : const SizedBox.shrink();

    return LayeredPage(
      header: HeroHeader(
        title: l.supervisionTitle,
        subtitle: l.supervisionSubtitle,
        emoji: '🛰️',
        gradient: EcoGradients.violet,
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in ReportPeriod.values)
              EcoChip(
                label: periodLabel(l, p),
                selected: period == p,
                onTap: () => ref.read(statsPeriodProvider.notifier).set(p),
              ),
          ],
        ),
        if (stats == null)
          Center(child: loading ? const CircularProgressIndicator() : Text(l.dashEmpty))
        else ...[
          ResponsiveGrid(
            children: [
              StatTile(emoji: '⚖️', value: fmtKg(context, stats.tonnes), label: l.statTonnes),
              StatTile(emoji: '🚚', value: '${stats.completed}', label: l.statCompleted, gradient: EcoGradients.sky),
              StatTile(
                emoji: '🌍',
                value: l.kg(fmtKg(context, stats.co2Kg)),
                label: l.statCo2,
                gradient: EcoGradients.green,
              ),
              StatTile(
                emoji: '👥',
                value: '${stats.activeTotal}',
                label: l.statActiveUsers,
                gradient: EcoGradients.violet,
              ),
            ],
          ),
          SectionTitle('♻️ ${l.dashByMaterial}'),
          EcoCard(
            child: stats.kgByMaterial.isEmpty
                ? Text(l.dashEmpty)
                : Column(
                    children: [
                      for (final e in (stats.kgByMaterial.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value))))
                        ShareBar(
                          label: '${materialEmoji(e.key)} ${materialLabel(l, e.key)}',
                          value: '${l.kg(fmtKg(context, e.value))} · ${(e.value / stats.totalKg * 100).round()} %',
                          fraction: e.value / stats.kgByMaterial.values.reduce((a, b) => a > b ? a : b),
                          color: materialColor(e.key),
                        ),
                    ],
                  ),
          ),
          SectionTitle('⚙️ ${l.perfTitle}'),
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, (k, v)) in _kpis(l, context, stats).indexed)
                  EcoListTile(
                    leading: EcoAvatar(text: ['🤝', '⏱️', '✅', '🧠', '❌', '👤'][i % 6]),
                    title: v,
                    subtitle: k,
                    showDivider: i < 5,
                  ),
              ],
            ),
          ),
          Text(
            [
              for (final e in stats.activeUsers.entries) '${roleLabel(l, e.key)} : ${e.value}',
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          ResponsiveGrid(
            children: [
              for (final pdf in [true, false])
                EcoButton(
                  label: pdf ? l.exportPdf : l.exportExcel,
                  leading: pdf ? '📄' : '📗',
                  style: pdf ? EcoButtonStyle.coral : EcoButtonStyle.ghost,
                  loading: state.isLoading,
                  onPressed: () => ref
                      .read(adminControllerProvider.notifier)
                      .export(stats, _labels(context, stats, period), pdf: pdf),
                ),
            ],
          ),
        ],
        SectionTitle('🧰 ${l.adminTools}'),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              tool('👥', l.usersTitle, l.usersSubtitle, Routes.adminUsers, show: can(AdminPermission.users)),
              tool('🪪', l.verifTitle, l.verifSubtitle, Routes.verifications,
                  badge: pending, show: can(AdminPermission.verifications)),
              tool('🗺️', l.liveMapTitle, l.liveMapSubtitle, Routes.liveMap),
              tool('⚖️', l.disputesTitle, l.disputesSubtitle, Routes.disputes,
                  badge: disputes, show: can(AdminPermission.disputes)),
              tool('🧹', l.modTitle, l.modSubtitle, Routes.moderation, show: can(AdminPermission.market)),
              tool('📣', l.broadcastTitle, l.broadcastSubtitle, Routes.broadcast, show: can(AdminPermission.broadcast)),
              tool('📍', l.zonesTitle, l.zonesSubtitle, Routes.zones, show: can(AdminPermission.zones)),
              tool('🔐', l.adminsTitle, l.adminsSubtitle, Routes.admins, show: me?.isSuperAdmin ?? false),
              tool('📜', l.auditTitle, l.auditSubtitle, Routes.audit, show: can(AdminPermission.audit)),
              tool('🧠', l.navModel, l.forecastAdminSubtitle, Routes.model),
            ],
          ),
        ),
      ],
    );
  }

  static List<(String, String)> _kpis(AppLocalizations l, BuildContext c, PlatformStats s) => [
    (l.perfMatching, '${(s.matchingRate * 100).round()} %'),
    (l.perfAcceptDelay, s.avgAcceptMinutes == null ? '—' : l.minutes(s.avgAcceptMinutes!.round())),
    (l.perfCompletion, s.avgCompletionHours == null ? '—' : l.hours(s.avgCompletionHours!.round())),
    (l.perfAi, s.aiAccuracy == null ? '—' : '${(s.aiAccuracy! * 100).round()} %'),
    (l.perfCancel, '${(s.cancelRate * 100).round()} %'),
    (l.perfRequests, '${s.requests}'),
  ];

  PlatformReportLabels _labels(BuildContext context, PlatformStats s, ReportPeriod p) {
    final l = context.l10n;
    return PlatformReportLabels(
      title: l.platformReportTitle,
      period: periodLabel(l, p),
      generatedOn: l.reportGenerated(fmtDate(context, DateTime.now())),
      kpis: [
        (l.statTonnes, fmtKg(context, s.tonnes)),
        (l.statCompleted, '${s.completed}'),
        (l.statCo2, l.kg(fmtKg(context, s.co2Kg))),
        (l.statActiveUsers, '${s.activeTotal}'),
        ..._kpis(l, context, s),
      ],
      byMaterial: l.dashByMaterial,
      material: l.reportMaterial,
      share: l.reportShare,
      materialName: (n) => materialLabel(l, materialFromName(n)),
      methodNote: l.docCertificateMethod,
    );
  }
}
