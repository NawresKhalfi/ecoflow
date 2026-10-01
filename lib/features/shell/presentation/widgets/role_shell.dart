import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
import '../../../collection/application/proposal_watcher.dart';
import '../../../forecast/application/forecast_providers.dart';
import '../../../impact/application/impact_providers.dart';
import '../../../missions/application/collector_controllers.dart';
import '../../../routing/presentation/widgets/tour_entry_cards.dart';
import '../../../tracking/application/tracking_providers.dart';
import '../../../tracking/presentation/widgets/notification_listener.dart';
import '../../../estimation/application/estimation_providers.dart';
import '../../../estimation/domain/estimate_record.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../domain/nav_destinations.dart';

/// Coque de navigation de l'espace connecté : barre latérale sur grand
/// écran (≥ 900 px), barre flottante en bas sur mobile.
class RoleShell extends ConsumerWidget {
  const RoleShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const breakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider).role ?? UserRole.citizen;
    final items = destinationsFor(role);
    final active = activeDestination(items, location);
    final wide = MediaQuery.sizeOf(context).width >= breakpoint;
    if (role == UserRole.citizen) _notifyWeighed(context, ref);
    listenNotifications(context, ref);
    ref.watch(pushRegistrationProvider);
    if (role == UserRole.citizen) ref.watch(proposalWatcherProvider);
    if (role == UserRole.citizen) ref.watch(challengeSyncProvider);
    if (role == UserRole.admin) ref.watch(autoRetrainProvider);
    if (role == UserRole.collector) {
      ref.watch(earningsSyncProvider);
      listenTourChanges(context, ref);
      ref.watch(livePublisherProvider);
    }
    void go(NavDestination d) => context.go(d.route);

    if (wide) {
      return Scaffold(
        body: EcoBackground(
          child: Row(
            children: [
              _SideNav(items: items, active: active, onSelect: go),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: EcoBackground(child: child),
      bottomNavigationBar: _BottomNav(items: items, active: active, onSelect: go),
    );
  }
}

/// Notification du montant final quand une pesée est validée (US-029).
void _notifyWeighed(BuildContext context, WidgetRef ref) {
  ref.listen<AsyncValue<List<EstimateRecord>>>(myEstimatesProvider, (prev, next) {
    final before = {for (final r in prev?.value ?? const <EstimateRecord>[]) r.code: r.isWeighed};
    for (final r in next.value ?? const <EstimateRecord>[]) {
      if (r.isWeighed && before[r.code] == false) {
        final amount = context.l10n.dt(fmtDt(context, r.weighing!.finalDt));
        showEcoToast(context, '✅ ${context.l10n.estWeighedNotice(amount)}');
      }
    }
  });
}

String navLabel(AppLocalizations l, NavDestination d) => switch (d) {
  NavDestination.home => l.navHome,
  NavDestination.scan => l.navScan,
  NavDestination.estimates => l.navEstimates,
  NavDestination.wallet => l.navWallet,
  NavDestination.collections => l.navCollections,
  NavDestination.weighing => l.navWeighing,
  NavDestination.missions => l.navMissions,
  NavDestination.earnings => l.navEarnings,
  NavDestination.receptions => l.navReceptions,
  NavDestination.dashboard => l.navDashboard,
  NavDestination.stock => l.navStock,
  NavDestination.market => l.navMarket,
  NavDestination.supervision => l.navSupervision,
  NavDestination.pricing => l.navPricing,
  NavDestination.catalog => l.navCatalog,
  NavDestination.model => l.navModel,
  NavDestination.addresses => l.navAddresses,
  NavDestination.documents => l.navDocuments,
  NavDestination.company => l.navCompany,
  NavDestination.profile => l.navProfile,
};

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.horizontal,
  });

  final NavDestination item;
  final bool selected;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final label = navLabel(context.l10n, item);
    final fg = selected ? Colors.white : eco.muted;
    final children = [
      ExcludeSemantics(child: Text(item.emoji, style: const TextStyle(fontSize: 22))),
      SizedBox(width: horizontal ? 12 : 0, height: horizontal ? 0 : 2),
      horizontal
          ? Text(label, style: AppTheme.weighted(15, 600, color: fg))
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, maxLines: 1, style: AppTheme.weighted(11, 600, color: fg)),
            ),
    ];
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Pressable(
        lift: 0,
        onTap: onTap,
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            // Pas de courbe à dépassement : l'interpolation des ombres
            // produirait un flou négatif (assertion en mode debug).
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              horizontal && selected ? 6 : 0,
              !horizontal && selected ? -6 : 0,
              0,
            ),
            padding: horizontal
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 13)
                : const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              gradient: selected ? EcoGradients.green : null,
              color: selected ? null : (horizontal ? null : eco.card),
              borderRadius: BorderRadius.circular(20),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: EcoColors.primary.withValues(alpha: .5),
                        blurRadius: 18,
                        spreadRadius: -8,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : (horizontal ? null : eco.softShadow),
            ),
            child: horizontal
                ? Row(children: children)
                : Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.items, required this.active, required this.onSelect});

  final List<NavDestination> items;
  final NavDestination? active;
  final ValueChanged<NavDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    return SizedBox(
      width: 250,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, bottom: 20),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: '♻️ Eco'),
                      const TextSpan(
                        text: 'Flow',
                        style: TextStyle(color: EcoColors.primary),
                      ),
                    ],
                  ),
                  style: AppTheme.weighted(26, 800, color: eco.ink),
                ),
              ),
              for (final d in items) ...[
                _NavButton(
                  item: d,
                  selected: d == active,
                  horizontal: true,
                  onTap: () => onSelect(d),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.items, required this.active, required this.onSelect});

  final List<NavDestination> items;
  final NavDestination? active;
  final ValueChanged<NavDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final bg = context.eco.background;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 18, 12, 12 + MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.withValues(alpha: 0), bg],
          stops: const [0, .6],
        ),
      ),
      // Boutons flexibles : 4 onglets tiennent sur les plus petits écrans.
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 96.0 * items.length),
          child: Row(
            children: [
              for (final d in items)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _NavButton(
                      item: d,
                      selected: d == active,
                      horizontal: false,
                      onTap: () => onSelect(d),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
