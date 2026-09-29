import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'motion.dart';

/// Carte superposée : grands arrondis, ombre douce en deux couches,
/// fond blanc ou dégradé expressif, forme décorative optionnelle.
class EcoCard extends StatelessWidget {
  const EcoCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.decorated = false,
    this.radius = 28,
    this.semanticLabel,
  });

  final Widget child;
  final Gradient? gradient;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Ajoute un cercle translucide dans le coin (profondeur).
  final bool decorated;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final card = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: gradient == null ? eco.card : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: eco.softShadow,
      ),
      child: Stack(children: [
        if (decorated)
          PositionedDirectional(
            end: -24,
            bottom: -24,
            child: _Blob(size: 96, color: Colors.white.withValues(alpha: .18)),
          ),
        Padding(padding: padding, child: child),
      ]),
    );
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, child: card);
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}

/// Cercle décoratif réutilisable (headers, tuiles).
class DecorCircle extends StatelessWidget {
  const DecorCircle({super.key, required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => _Blob(size: size, color: color);
}
