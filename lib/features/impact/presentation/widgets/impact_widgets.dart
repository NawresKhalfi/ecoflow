import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';

/// Bouton retour translucide posé sur le hero.
class HeroBack extends StatelessWidget {
  const HeroBack({super.key, required this.to});
  final String to;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: context.l10n.commonBack,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: .22),
      foregroundColor: Colors.white,
    ),
    onPressed: () => context.go(to),
    icon: const BackButtonIcon(),
  );
}

/// Carte de navigation : emoji, titre, sous-titre et chevron.
class LinkCard extends StatelessWidget {
  const LinkCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.gradient,
    this.compact = false,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Gradient? gradient;

  /// Tuile étroite (grille) : emoji au-dessus du texte, sans chevron.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final onGradient = gradient != null;
    if (compact) {
      return EcoCard(
        gradient: gradient,
        onTap: onTap,
        semanticLabel: title,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EcoAvatar(text: emoji),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }
    return EcoCard(
      gradient: gradient,
      decorated: onGradient,
      onTap: onTap,
      semanticLabel: title,
      child: Row(
        children: [
          onGradient
              ? ExcludeSemantics(child: Text(emoji, style: const TextStyle(fontSize: 38)))
              : EcoAvatar(text: emoji),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: onGradient
                      ? AppTheme.weighted(19, 800, color: Colors.white)
                      : Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  subtitle,
                  style: onGradient
                      ? AppTheme.weighted(14, 500, color: Colors.white.withValues(alpha: .92))
                      : Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            onGradient ? Icons.arrow_forward_rounded : Icons.chevron_right,
            color: onGradient ? Colors.white : context.eco.muted,
          ),
        ],
      ),
    );
  }
}

/// Barre de progression arrondie (objectif collectif d'un défi).
class ProgressPill extends StatelessWidget {
  const ProgressPill({super.key, required this.value, this.color = EcoColors.primary});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(
      value: value.clamp(0, 1),
      minHeight: 12,
      color: color,
      backgroundColor: context.eco.muted.withValues(alpha: .14),
    ),
  );
}
