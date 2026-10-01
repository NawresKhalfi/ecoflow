import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../domain/impact.dart';

/// Kilos recyclés par mois (US-118) : une seule série, mois en cours
/// accentué, valeur au toucher et pour le lecteur d'écran.
class MonthlyBars extends StatefulWidget {
  const MonthlyBars({super.key, required this.months, this.height = 140});

  final List<MonthStat> months;
  final double height;

  @override
  State<MonthlyBars> createState() => _MonthlyBarsState();
}

class _MonthlyBarsState extends State<MonthlyBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eco = context.eco;
    final lang = Localizations.localeOf(context).languageCode;
    final months = widget.months;
    final max = months.fold(0.0, (a, m) => m.kg > a ? m.kg : a);
    final shown = _selected ?? months.length - 1;
    String name(DateTime d) => DateFormat.MMM(lang).format(d);
    return Semantics(
      label: [
        for (final m in months)
          '${DateFormat.yMMMM(lang).format(m.month)} ${l.kg(fmtKg(context, m.kg))}',
      ].join(', '),
      child: ExcludeSemantics(
        child: SizedBox(
          height: widget.height + 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, m) in months.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selected = _selected == i ? null : i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 18,
                            child: i == shown
                                ? FittedBox(
                                    child: Text(
                                      fmtKg(context, m.kg),
                                      style: AppTheme.weighted(12, 700, color: eco.ink),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            height: max == 0
                                ? 3
                                : (m.kg / max * widget.height).clamp(3, widget.height),
                            decoration: BoxDecoration(
                              color: i == months.length - 1
                                  ? EcoColors.primary
                                  : EcoColors.primary.withValues(alpha: i == shown ? .75 : .4),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            child: Text(
                              name(m.month),
                              style: AppTheme.weighted(
                                11,
                                i == months.length - 1 ? 700 : 500,
                                color: i == months.length - 1 ? eco.ink : eco.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
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
