import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';

/// Barres des gains des 7 derniers jours : une seule série (une teinte, pas
/// de légende), barres fines arrondies ancrées à la base, valeur au toucher,
/// valeurs exposées au lecteur d'écran.
class EarningsBars extends StatefulWidget {
  const EarningsBars({super.key, required this.values, required this.lastDay});

  final List<double> values;
  final DateTime lastDay;

  @override
  State<EarningsBars> createState() => _EarningsBarsState();
}

class _EarningsBarsState extends State<EarningsBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final eco = context.eco;
    final lang = Localizations.localeOf(context).languageCode;
    final days = [for (var i = 6; i >= 0; i--) widget.lastDay.subtract(Duration(days: i))];
    final max = widget.values.fold(0.0, (a, b) => b > a ? b : a);
    final description = [
      for (final (i, d) in days.indexed)
        '${DateFormat.E(lang).format(d)} ${context.l10n.dt(fmtDt(context, widget.values[i]))}',
    ].join(', ');
    return Semantics(
      label: description,
      child: ExcludeSemantics(
        child: SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, d) in days.indexed)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _selected = _selected == i ? null : i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 18,
                            child: _selected == i
                                ? FittedBox(
                                    child: Text(
                                      fmtDt(context, widget.values[i]),
                                      style: AppTheme.weighted(12, 700, color: eco.ink),
                                    ),
                                  )
                                : null,
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOutCubic,
                            height: max == 0 ? 2 : 2 + 104 * widget.values[i] / max,
                            decoration: BoxDecoration(
                              color: _selected == null || _selected == i
                                  ? EcoColors.primaryBright
                                  : EcoColors.primaryBright.withValues(alpha: .4),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat.E(lang).format(d),
                            style: AppTheme.weighted(11, 600, color: eco.muted),
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
