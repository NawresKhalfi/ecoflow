import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';

/// Gabarit des écrans d'authentification : hero illustré + carte formulaire
/// qui le chevauche ; sur grand écran, carte centrée plus étroite.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.emoji = '♻️',
    this.gradient = EcoGradients.green,
    this.footer = const [],
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final Gradient gradient;
  final List<Widget> children;
  final List<Widget> footer;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      body: EcoBackground(
        child: LayeredPage(
          bottomPadding: 48,
          header: HeroHeader(
            title: title,
            subtitle: subtitle,
            emoji: emoji,
            gradient: gradient,
            leading: showBack && canPop
                ? IconButton.filledTonal(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: .22),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const BackButtonIcon(),
                  )
                : null,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: EcoCard(
                  padding: const EdgeInsets.all(22),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
              ),
            ),
            for (final f in footer)
              Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: f),
              ),
          ],
        ),
      ),
    );
  }
}
