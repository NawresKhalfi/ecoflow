import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'eco_card.dart';
import 'motion.dart';

/// Largeur maximale du contenu (lisibilité sur tablette / desktop).
const contentMaxWidth = 1040.0;

/// Fond teinté avec halos colorés (cf. `body` du prototype).
class EcoBackground extends StatelessWidget {
  const EcoBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    return DecoratedBox(
      decoration: BoxDecoration(color: eco.background),
      child: Stack(
        fit: StackFit.expand,

        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(.8, -1),
                  radius: .9,
                  colors: [EcoColors.sun.withValues(alpha: .22), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-1, .2),
                  radius: .9,
                  colors: [EcoColors.sky.withValues(alpha: .14), Colors.transparent],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// En-tête illustré en dégradé, bas arrondi, formes décoratives.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.gradient = EcoGradients.green,
    this.emoji,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final Gradient gradient;

  /// Illustration géante en filigrane.
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(wide ? 56 : 44)),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -70,
            top: -80,
            child: DecorCircle(size: 240, color: Colors.white.withValues(alpha: .12)),
          ),
          PositionedDirectional(
            end: 90,
            bottom: -60,
            child: DecorCircle(size: 140, color: EcoColors.sun.withValues(alpha: .35)),
          ),
          if (emoji != null)
            PositionedDirectional(
              end: wide ? 60 : 12,
              bottom: 58,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: .28,
                  child: Text(emoji!, style: const TextStyle(fontSize: 92)),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              wide ? 40 : 22,
              top + (wide ? 40 : 22),
              wide ? 40 : 22,
              wide ? 110 : 100,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[leading!, const SizedBox(height: 12)],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTheme.weighted(
                              wide ? 46 : 32,
                              800,
                              color: Colors.white,
                              height: 1.05,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        if (trailing != null) trailing!,
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        subtitle!,
                        style: AppTheme.weighted(
                          17,
                          500,
                          color: Colors.white.withValues(alpha: .9),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page type : hero + contenu qui chevauche le hero (effet de couches),
/// enfants animés en cascade.
class LayeredPage extends StatelessWidget {
  const LayeredPage({
    super.key,
    required this.header,
    required this.children,
    this.bottomPadding = 120,
  });

  final Widget header;
  final List<Widget> children;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    // Une seule colonne (et non des slivers) : le contenu est peint après le
    // hero et le recouvre bien, alors qu'un Viewport peint le premier sliver
    // au-dessus des suivants.
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          Transform.translate(
            offset: const Offset(0, -66),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  // Le décalage de -66 laisse déjà 66 px libres en bas.
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    (bottomPadding - 66).clamp(0, double.infinity),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < children.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        Entrance(index: i, child: children[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grille responsive : colonnes de [minItemWidth] minimum.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 290,
    this.spacing = 16,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / minItemWidth).floor().clamp(1, children.length.clamp(1, 6));
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      },
    );
  }
}
