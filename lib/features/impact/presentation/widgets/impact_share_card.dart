import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../wallet/domain/gamification.dart';
import '../../domain/impact.dart';

String fmtWhole(BuildContext c, double v) =>
    NumberFormat('#,##0', Localizations.localeOf(c).languageCode).format(v.round());

/// Carte visuelle partagée sur les réseaux (US-122) : format portrait 4:5.
class ImpactShareCard extends StatelessWidget {
  const ImpactShareCard({
    super.key,
    required this.impact,
    required this.firstName,
    required this.level,
  });

  final PersonalImpact impact;
  final String firstName;
  final EcoLevel level;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final white = Colors.white;
    TextStyle s(double size, int w, [double alpha = 1]) =>
        AppTheme.weighted(size, w, color: white.withValues(alpha: alpha));
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B7A4B), Color(0xFF19B26B), Color(0xFF4C9AFF)],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -60,
              child: _Circle(size: 220, color: white.withValues(alpha: .14)),
            ),
            Positioned(
              left: -40,
              bottom: -70,
              child: _Circle(size: 200, color: white.withValues(alpha: .10)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('♻️ EcoFlow', style: s(16, 800)),
                  const Spacer(),
                  Text(l.shareCardHeadline(firstName), style: s(18, 600, .92)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(l.kg(fmtKg(context, impact.totalKg)), style: s(52, 800)),
                  ),
                  Text(l.shareCardRecycled(impact.collections), style: s(16, 600, .92)),
                  const SizedBox(height: 18),
                  _Line(emoji: '🌍', text: l.co2Avoided(fmtKg(context, impact.co2Kg))),
                  _Line(emoji: '🚗', text: l.eqCarKm(fmtWhole(context, impact.carKm))),
                  _Line(emoji: '🌳', text: l.eqTrees(fmtKg(context, impact.treeYears))),
                  const Spacer(),
                  Row(
                    children: [
                      Text(level.emoji, style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.shareCardJoin, style: s(14, 600, .92))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: AppTheme.weighted(15, 700, color: Colors.white)),
        ),
      ],
    ),
  );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// Rend la carte en PNG (3×) dans [dir] et renvoie le chemin du fichier.
Future<String> captureCard(GlobalKey key, Directory dir) async {
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/ecoflow-impact-${DateTime.now().millisecondsSinceEpoch}.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file.path;
}

/// Couleur d'accent d'une part de CO₂ par catégorie (rang fixe, jamais cyclé).
Color categoryColor(int rank) => switch (rank) {
  0 => EcoColors.primary,
  1 => EcoColors.skyDeep,
  2 => EcoColors.violet,
  3 => EcoColors.sunDeep,
  _ => const Color(0xFF8A9A92),
};
