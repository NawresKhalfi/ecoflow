import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Bandeau d'erreur clair et visible (US-001 : « erreurs claires »).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = context.eco.chipCoral;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          const ExcludeSemantics(child: Text('⚠️', style: TextStyle(fontSize: 18))),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTheme.weighted(14, 600, color: fg))),
        ]),
      ),
    );
  }
}
