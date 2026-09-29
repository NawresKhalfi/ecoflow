import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../domain/detection.dart';
import '../../domain/scan_rules.dart';
import '../../domain/waste_category.dart';
import 'scan_labels.dart';

const _tones = [ChipTone.green, ChipTone.sun, ChipTone.sky, ChipTone.coral, ChipTone.violet];

/// Nombre d'objets par catégorie et total (US-014).
class CountsCard extends StatelessWidget {
  const CountsCard({super.key, required this.detections, required this.catalog});

  final List<Detection> detections;
  final List<WasteCategory> catalog;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = languageOf(context);
    final counts = countByCategory(detections, catalog);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.scanResultTitle, style: Theme.of(context).textTheme.titleLarge),
              ),
              EcoChip(label: l.scanTotal(detections.length), tone: ChipTone.violet),
            ],
          ),
          const SizedBox(height: 10),
          if (counts.isEmpty)
            Text(l.scanNoObject, style: Theme.of(context).textTheme.bodyMedium)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, e) in counts.entries.indexed)
                  EcoChip(
                    tone: _tones[i % _tones.length],
                    label: l.scanCount(
                      categoryById(catalog, e.key).emoji,
                      categoryById(catalog, e.key).name(lang),
                      e.value,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Recyclabilité estimée et explication (US-015).
class RecyclabilityCard extends StatelessWidget {
  const RecyclabilityCard({super.key, required this.estimate, required this.catalog});

  final RecyclabilityEstimate estimate;
  final List<WasteCategory> catalog;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = languageOf(context);
    final (gradient, fg) = switch (estimate.level) {
      Recyclability.high => (EcoGradients.green, Colors.white),
      Recyclability.medium => (EcoGradients.sun, EcoColors.onSun),
      Recyclability.low => (EcoGradients.coral, Colors.white),
    };
    final drivers = estimate.drivers.map((id) => categoryById(catalog, id).name(lang)).join(', ');
    return EcoCard(
      gradient: gradient,
      decorated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('♻️ ${l.scanRecyclabilityTitle}', style: AppTheme.weighted(15, 700, color: fg)),
          const SizedBox(height: 4),
          Text(recyclabilityLabel(l, estimate.level), style: AppTheme.weighted(32, 800, color: fg)),
          const SizedBox(height: 6),
          Text(
            '${l.recycMostly(drivers)} ${recyclabilityExplanation(l, estimate.level)}',
            style: AppTheme.weighted(15, 500, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Indice de confiance et seuil réglable (US-013).
class ConfidenceCard extends StatelessWidget {
  const ConfidenceCard({
    super.key,
    required this.confidence,
    required this.threshold,
    required this.onThreshold,
  });

  final double? confidence;
  final double threshold;
  final ValueChanged<double> onThreshold;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final c = confidence;
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.scanConfidenceTitle, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (c != null) EcoChip(label: l.percent((c * 100).round())),
            ],
          ),
          if (c != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: LinearProgressIndicator(
                value: c,
                minHeight: 12,
                backgroundColor: context.eco.line,
                color: EcoColors.coral,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Text(l.scanThreshold, style: Theme.of(context).textTheme.titleSmall)),
              EcoChip(label: l.percent((threshold * 100).round()), tone: ChipTone.sky),
            ],
          ),
          Slider(
            value: threshold,
            min: inferenceFloor,
            max: .95,
            divisions: 17,
            label: l.percent((threshold * 100).round()),
            onChanged: onThreshold,
          ),
          Text(l.scanThresholdHelp, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
