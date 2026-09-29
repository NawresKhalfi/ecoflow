import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../domain/waste_category.dart';
import 'scan_labels.dart';

/// Feuille de choix d'une catégorie du catalogue.
Future<String?> pickCategory(BuildContext context, List<WasteCategory> catalog, {String? current}) {
  final lang = languageOf(context);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.scanChooseCategory, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in catalog.where((c) => c.active))
                  EcoChip(
                    label: '${c.emoji} ${c.name(lang)}',
                    selected: c.id == current,
                    onTap: () => Navigator.pop(ctx, c.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
