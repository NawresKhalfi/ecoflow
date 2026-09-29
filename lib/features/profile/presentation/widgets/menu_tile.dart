import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';

/// Entrée de menu du profil.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.trailing,
    this.gradient,
    this.showDivider = true,
    this.danger = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final Gradient? gradient;
  final bool showDivider;
  final bool danger;

  @override
  Widget build(BuildContext context) => EcoListTile(
        leading: EcoAvatar(text: emoji, gradient: gradient, size: 42),
        title: label,
        showDivider: showDivider,
        onTap: onTap,
        trailing: trailing ??
            Icon(Icons.chevron_right,
                color: danger ? const Color(0xFFC4482A) : context.eco.muted),
      );
}
