import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../domain/detection.dart';
import '../../domain/waste_category.dart';
import 'category_picker.dart';
import 'scan_labels.dart';

/// Correction manuelle du résultat (US-016).
class CorrectionCard extends StatelessWidget {
  const CorrectionCard({
    super.key,
    required this.detections,
    required this.catalog,
    required this.onRelabel,
    required this.onRemove,
    required this.onAdd,
    required this.onSave,
    required this.saving,
    required this.saved,
    required this.consent,
    required this.onConsent,
  });

  final List<Detection> detections;
  final List<WasteCategory> catalog;
  final void Function(String id, String category) onRelabel;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onAdd;
  final VoidCallback? onSave;
  final bool saving;
  final bool saved;
  final bool consent;
  final ValueChanged<bool> onConsent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = languageOf(context);
    return EcoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('✏️ ${l.scanCorrectTitle}', style: Theme.of(context).textTheme.titleMedium),
          Text(l.scanCorrectHelp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          for (final (i, d) in detections.indexed)
            EcoListTile(
              leading: EcoAvatar(text: categoryById(catalog, d.categoryId).emoji),
              title: categoryById(catalog, d.categoryId).name(lang),
              subtitle: d.source == DetectionSource.manual
                  ? l.scanManual
                  : '${l.percent((d.confidence * 100).round())}${d.rawLabel == null ? '' : ' · ${d.rawLabel}'}',
              showDivider: i < detections.length - 1,
              onTap: () async {
                final c = await pickCategory(context, catalog, current: d.categoryId);
                if (c != null) onRelabel(d.id, c);
              },
              trailing: IconButton(
                tooltip: l.addressDelete,
                icon: const Icon(Icons.delete_outline, color: Color(0xFFC4482A)),
                onPressed: () => onRemove(d.id),
              ),
            ),
          const SizedBox(height: 8),
          EcoButton(
            label: l.scanAddObject,
            leading: '➕',
            style: EcoButtonStyle.ghost,
            onPressed: () async {
              final c = await pickCategory(context, catalog);
              if (c != null) onAdd(c);
            },
          ),
          const SizedBox(height: 8),
          MergeSemantics(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.scanTrainingConsent, style: Theme.of(context).textTheme.bodyMedium),
              value: consent,
              onChanged: onConsent,
            ),
          ),
          const SizedBox(height: 8),
          EcoButton(
            label: saved ? l.scanCorrectionsSaved : l.scanSaveCorrections,
            style: saved ? EcoButtonStyle.green : EcoButtonStyle.coral,
            leading: saved ? '✅' : '💾',
            loading: saving,
            onPressed: saved ? null : onSave,
          ),
        ],
      ),
    );
  }
}

/// Alerte qualité photo avec conseils (US-017).
class QualityAlert extends StatelessWidget {
  const QualityAlert({super.key, required this.messages, required this.onRetake});

  final List<String> messages;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return EcoCard(
      gradient: EcoGradients.sun,
      decorated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚠️ ${l.issueTitle}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: EcoColors.onSun),
          ),
          const SizedBox(height: 6),
          for (final m in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $m', style: const TextStyle(color: EcoColors.onSun)),
            ),
          const SizedBox(height: 8),
          EcoButton(
            label: l.scanRetake,
            leading: '📷',
            style: EcoButtonStyle.ghost,
            expand: false,
            onPressed: onRetake,
          ),
        ],
      ),
    );
  }
}
