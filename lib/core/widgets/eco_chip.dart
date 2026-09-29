import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

enum ChipTone { green, coral, sun, sky, violet }

/// Pastille colorée (statut, catégorie) ou sélectionnable.
class EcoChip extends StatelessWidget {
  const EcoChip({
    super.key,
    required this.label,
    this.tone = ChipTone.green,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final ChipTone tone;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final (bg, fg) = switch (tone) {
      ChipTone.green => eco.chipGreen,
      ChipTone.coral => eco.chipCoral,
      ChipTone.sun => eco.chipSun,
      ChipTone.sky => eco.chipSky,
      ChipTone.violet => eco.chipViolet,
    };
    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? EcoColors.primary : bg,
        borderRadius: BorderRadius.circular(99),
        boxShadow: selected
            ? [
                BoxShadow(
                    color: EcoColors.primary.withValues(alpha: .5),
                    blurRadius: 16,
                    spreadRadius: -6,
                    offset: const Offset(0, 8)),
              ]
            : null,
      ),
      child: Text(label, style: AppTheme.weighted(13, 600, color: selected ? Colors.white : fg)),
    );
    if (onTap == null) return chip;
    return Semantics(
      selected: selected,
      child: Pressable(lift: 0, onTap: onTap, semanticLabel: label, child: ExcludeSemantics(child: chip)),
    );
  }
}
