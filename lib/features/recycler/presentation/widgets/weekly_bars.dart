import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';

/// Kilos reçus par semaine (de la plus ancienne à la plus récente), avec
/// la valeur au-dessus de la barre la plus haute et de la dernière.
class WeeklyBars extends StatelessWidget {
  const WeeklyBars({super.key, required this.values, this.height = 120});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eco = context.eco;
    final max = values.fold(0.0, (a, b) => b > a ? b : a);
    final peak = values.indexOf(max);
    return Semantics(
      label: l.dashWeeklySemantics(
        values.length,
        l.kg(fmtKg(context, values.isEmpty ? 0 : values.last)),
      ),
      child: ExcludeSemantics(
        child: SizedBox(
          height: height + 36,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, v) in values.indexed)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (v > 0 && (i == peak || i == values.length - 1))
                          FittedBox(
                            child: Text(
                              fmtKg(context, v),
                              style: TextStyle(fontSize: 11, color: eco.muted),
                            ),
                          ),
                        const SizedBox(height: 2),
                        Container(
                          height: max == 0 ? 2 : (v / max * height).clamp(2, height),
                          decoration: BoxDecoration(
                            color: i == values.length - 1
                                ? EcoColors.primary
                                : EcoColors.primary.withValues(alpha: .45),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          child: Text(
                            i == values.length - 1 ? l.dashThisWeek : 'S${i - values.length + 1}',
                            style: TextStyle(fontSize: 10, color: eco.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
