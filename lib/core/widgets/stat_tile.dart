import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'eco_card.dart';
import 'motion.dart';

/// Tuile de statistique en dégradé, avec emoji et cercle décoratif.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.emoji,
    required this.value,
    required this.label,
    this.gradient = EcoGradients.green,
    this.foreground = Colors.white,
  });

  final String emoji;
  final String value;
  final String label;
  final Gradient gradient;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      lift: 4,
      tilt: -.017,
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: context.eco.softShadow,
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          PositionedDirectional(
            end: -36,
            bottom: -36,
            child: DecorCircle(size: 70, color: Colors.white.withValues(alpha: .18)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 22))),
            const SizedBox(height: 4),
            Text(value, style: AppTheme.weighted(26, 800, color: foreground)),
            Text(label, style: AppTheme.weighted(13, 500, color: foreground)),
          ]),
        ]),
      ),
    );
  }
}
