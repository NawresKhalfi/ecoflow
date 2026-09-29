import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../domain/user_role.dart';
import '../widgets/auth_messages.dart';
import '../widgets/role_picker.dart';

/// Page d'accueil (non connecté) : promesse, choix d'espace, connexion.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eco = context.eco;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Scaffold(
      body: EcoBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Entrance(
                    child: Row(children: [
                      EcoChip(label: l.welcomeBadge),
                      const Spacer(),
                      IconButton.filledTonal(
                        tooltip: l.welcomeLanguage,
                        onPressed: () => context.push(Routes.language),
                        icon: const Icon(Icons.translate),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Entrance(
                    index: 1,
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${l.welcomeTitleA} '),
                        TextSpan(text: l.welcomeTitleB, style: const TextStyle(color: EcoColors.primary)),
                      ]),
                      style: AppTheme.weighted(wide ? 72 : 44, 800,
                          color: eco.ink, height: .98, letterSpacing: wide ? -3 : -1.6),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Entrance(
                    index: 2,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(l.welcomeSubtitle,
                          style: AppTheme.weighted(19, 400, color: eco.muted, height: 1.4)),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Entrance(
                    index: 3,
                    child: Text(l.welcomeChooseSpace, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: 14),
                  Entrance(
                    index: 4,
                    child: ResponsiveGrid(minItemWidth: 260, children: [
                      for (final r in UserRole.selectable) _RoleCard(role: r),
                    ]),
                  ),
                  const SizedBox(height: 26),
                  Entrance(
                    index: 5,
                    child: Wrap(spacing: 12, runSpacing: 12, children: [
                      SizedBox(
                        width: wide ? 280 : double.infinity,
                        child: EcoButton(
                          label: l.welcomeHaveAccount,
                          leading: '👋',
                          style: EcoButtonStyle.ghost,
                          onPressed: () => context.push(Routes.signIn),
                        ),
                      ),
                      SizedBox(
                        width: wide ? 280 : double.infinity,
                        child: EcoButton(
                          label: l.continueWithPhone,
                          leading: '📱',
                          style: EcoButtonStyle.green,
                          onPressed: () => context.push(Routes.phone),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Pressable(
      lift: 6,
      tilt: -.017,
      semanticLabel: roleLabel(l, role),
      onTap: () => context.push('${Routes.signUp}?role=${role.name}'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 170),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: roleGradient(role),
          borderRadius: BorderRadius.circular(30),
          boxShadow: context.eco.softShadow,
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          PositionedDirectional(
            end: -52,
            bottom: -52,
            child: DecorCircle(size: 110, color: Colors.white.withValues(alpha: .18)),
          ),
          ExcludeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(roleEmoji(role), style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 6),
              Text(roleLabel(l, role), style: AppTheme.weighted(24, 800, color: Colors.white)),
              const SizedBox(height: 4),
              Text(roleDescription(l, role),
                  style: AppTheme.weighted(15, 500, color: Colors.white.withValues(alpha: .92))),
            ]),
          ),
        ]),
      ),
    );
  }
}
