import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

enum EcoButtonStyle { coral, green, ghost }

/// Bouton expressif pleine largeur : dégradé, ombre colorée, compression
/// à l'appui, état de chargement.
class EcoButton extends StatelessWidget {
  const EcoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = EcoButtonStyle.coral,
    this.leading,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final EcoButtonStyle style;
  final String? leading;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final enabled = onPressed != null && !loading;
    final (gradient, glow, fg) = switch (style) {
      EcoButtonStyle.coral => (EcoGradients.coral, EcoColors.pink, Colors.white),
      EcoButtonStyle.green => (EcoGradients.green, EcoColors.primary, Colors.white),
      EcoButtonStyle.ghost => (null, eco.shadow, eco.ink),
    };
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: fg),
          )
        else ...[
          if (leading != null) ...[
            ExcludeSemantics(child: Text(leading!, style: const TextStyle(fontSize: 18))),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppTheme.weighted(16, 700, color: fg),
            ),
          ),
        ],
      ],
    );
    return Opacity(
      opacity: enabled || loading ? 1 : .5,
      child: Pressable(
        lift: 2,
        onTap: enabled ? onPressed : null,
        semanticLabel: label,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? eco.card : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: gradient == null
                ? eco.softShadow
                : [
                    BoxShadow(
                      color: glow.withValues(alpha: .45),
                      blurRadius: 22,
                      spreadRadius: -10,
                      offset: const Offset(0, 12),
                    ),
                  ],
          ),
          child: ExcludeSemantics(child: content),
        ),
      ),
    );
  }
}

/// Lien texte discret mais typé (actions secondaires).
class EcoLink extends StatelessWidget {
  const EcoLink({super.key, required this.label, required this.onPressed, this.color});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: color ?? EcoColors.primary,
      textStyle: AppTheme.weighted(15, 700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    child: Text(label),
  );
}
