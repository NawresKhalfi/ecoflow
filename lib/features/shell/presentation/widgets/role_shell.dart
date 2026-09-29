import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
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
    void go(NavDestination d) => context.go(d.route);

    if (wide) {
      return Scaffold(
        body: EcoBackground(
          child: Row(children: [
            _SideNav(items: items, active: active, onSelect: go),
            Expanded(child: child),
          ]),
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

String navLabel(AppLocalizations l, NavDestination d) => switch (d) {
      NavDestination.home => l.navHome,
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
      Text(label, style: AppTheme.weighted(horizontal ? 15 : 11, 600, color: fg)),
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
            curve: Curves.easeOutBack,
            transform: Matrix4.translationValues(
                horizontal && selected ? 6 : 0, !horizontal && selected ? -6 : 0, 0),
            padding: horizontal
                ? const EdgeInsets.symmetric(horizontal: 16, vertical: 13)
                : const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                          offset: const Offset(0, 10)),
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, bottom: 20),
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: '♻️ Eco'),
                  const TextSpan(text: 'Flow', style: TextStyle(color: EcoColors.primary)),
                ]),
                style: AppTheme.weighted(26, 800, color: eco.ink),
              ),
            ),
            for (final d in items) ...[
              _NavButton(item: d, selected: d == active, horizontal: true, onTap: () => onSelect(d)),
              const SizedBox(height: 6),
            ],
          ]),
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
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final d in items)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _NavButton(
                item: d, selected: d == active, horizontal: false, onTap: () => onSelect(d)),
          ),
      ]),
    );
  }
}
