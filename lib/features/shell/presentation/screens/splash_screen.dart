import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Écran d'attente pendant la restauration de session.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: EcoGradients.green),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('♻️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('EcoFlow', style: AppTheme.weighted(34, 800, color: Colors.white)),
            const SizedBox(height: 22),
            const SizedBox.square(
              dimension: 26,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
