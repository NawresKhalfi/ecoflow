import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

export 'eco_button.dart';
export 'eco_card.dart';
export 'eco_chip.dart';
export 'layered_page.dart';
export 'motion.dart';
export 'stat_tile.dart';

/// Titre de section à forte graisse.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
        child: Semantics(
          header: true,
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
      );
}

/// Pastille d'avatar arrondie (emoji ou initiales).
class EcoAvatar extends StatelessWidget {
  const EcoAvatar({super.key, required this.text, this.gradient, this.size = 46});
  final String text;
  final Gradient? gradient;
  final double size;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: gradient == null ? eco.chipGreen.$1 : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(size * .35),
      ),
      child: Text(text,
          style: AppTheme.weighted(size * .45, 800,
              color: gradient == null ? EcoColors.primary : Colors.white)),
    );
  }
}

/// Ligne de liste : avatar, titre, sous-titre, élément de fin.
class EcoListTile extends StatelessWidget {
  const EcoListTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: showDivider ? Border(bottom: BorderSide(color: eco.line)) : null,
        ),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: text.titleSmall),
              if (subtitle != null) Text(subtitle!, style: text.bodySmall),
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}

/// Toast flottant (retour d'action).
void showEcoToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2300)));
}
