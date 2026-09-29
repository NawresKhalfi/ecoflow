import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/scan_controller.dart';
import '../../domain/detection.dart';
import '../../domain/waste_category.dart';
import 'scan_labels.dart';

const _boxColors = [
  Color(0xFF19B26B),
  Color(0xFFF5A800),
  Color(0xFF4C9AFF),
  Color(0xFFFF7A59),
  Color(0xFF7B61FF),
];

/// Scène photo sombre (cf. `.ph` du prototype) : image, cadres détectés
/// avec libellé et score (US-013), ligne de balayage pendant l'analyse.
class PhotoStage extends StatelessWidget {
  const PhotoStage({
    super.key,
    required this.photo,
    required this.detections,
    required this.catalog,
    this.scanning = false,
    this.height = 300,
  });

  final ScanPhoto? photo;
  final List<Detection> detections;
  final List<WasteCategory> catalog;
  final bool scanning;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = photo;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B3D34), Color(0xFF4B6357)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (p == null)
            const Center(
              child: ExcludeSemantics(child: Text('🧴🥫📦', style: TextStyle(fontSize: 56))),
            )
          else
            Center(
              child: AspectRatio(
                aspectRatio: p.width / p.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(p.jpeg, fit: BoxFit.cover, gaplessPlayback: true),
                    for (final (i, d) in detections.where((d) => d.box != null).indexed)
                      _Box(
                        detection: d,
                        color: _boxColors[i % _boxColors.length],
                        label: categoryById(catalog, d.categoryId).name(languageOf(context)),
                        delay: i,
                      ),
                  ],
                ),
              ),
            ),
          if (scanning) const _ScanLine(),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.detection,
    required this.color,
    required this.label,
    required this.delay,
  });

  final Detection detection;
  final Color color;
  final String label;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final b = detection.box!;
    return LayoutBuilder(
      builder: (context, c) {
        final rect = Rect.fromLTRB(
          b.left * c.maxWidth,
          b.top * c.maxHeight,
          b.right * c.maxWidth,
          b.bottom * c.maxHeight,
        );
        return Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: Entrance(
                index: delay,
                child: Semantics(
                  label: '$label ${(detection.confidence * 100).round()} %',
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: color, width: 3),
                      borderRadius: BorderRadius.circular(12),
                      color: color.withValues(alpha: .12),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: rect.left,
              top: (rect.top - 22).clamp(0, c.maxHeight - 22),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '$label ${(detection.confidence * 100).round()}%',
                  style: AppTheme.weighted(12, 700, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Align(
        alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_c.value)),
        child: Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.white.withValues(alpha: .7), blurRadius: 22, spreadRadius: 6),
            ],
          ),
        ),
      ),
    );
  }
}
