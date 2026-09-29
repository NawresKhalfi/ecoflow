import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../scan/domain/waste_category.dart';
import '../../../scan/presentation/widgets/scan_labels.dart';
import '../../domain/weighing.dart';
import 'estimation_format.dart';

/// Comparatif estimé / réel par matière (US-028, US-029).
class ComparisonTable extends StatelessWidget {
  const ComparisonTable({
    super.key,
    required this.result,
    required this.catalog,
    this.pending = false,
  });

  final WeighingResult result;
  final List<WasteCategory> catalog;

  /// Pas encore pesé : seules les valeurs estimées sont affichées.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, line) in result.lines.indexed)
          EcoListTile(
            showDivider: i < result.lines.length - 1,
            leading: EcoAvatar(text: categoryById(catalog, line.categoryId).emoji, size: 42),
            title: categoryById(catalog, line.categoryId).name(languageOf(context)),
            subtitle: pending
                ? '${l.approxKg(fmtKg(context, line.estimatedKg))} · ${l.approxDt(fmtDt(context, line.estimatedDt))}'
                : '${l.estEstimated} ${l.kg(fmtKg(context, line.estimatedKg))} → '
                      '${l.estReal} ${l.kg(fmtKg(context, line.actualKg))}\n'
                      '${l.dt(fmtDt(context, line.estimatedDt))} → ${l.dt(fmtDt(context, line.finalDt))}',
            trailing: pending ? null : _DeltaChip(ratio: line.deltaRatio),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text(pending ? l.estTotal : l.estFinalAmount, style: text.titleMedium)),
            Text(
              pending
                  ? l.approxDt(fmtDt(context, result.estimatedDt))
                  : l.dt(fmtDt(context, result.finalDt)),
              style: text.titleLarge,
            ),
          ],
        ),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.ratio});
  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final r = ratio;
    if (r == null) return const EcoChip(label: '—', tone: ChipTone.sky);
    final pct = (r * 100).round();
    final tone = pct.abs() <= 10 ? ChipTone.green : (pct > 0 ? ChipTone.sky : ChipTone.coral);
    return EcoChip(label: '${pct > 0 ? '+' : ''}$pct %', tone: tone);
  }
}
