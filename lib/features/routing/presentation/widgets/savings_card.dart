import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../estimation/presentation/widgets/estimation_format.dart';
import '../../../missions/presentation/widgets/mission_labels.dart';
import '../../domain/tour.dart';

/// Économies estimées : km, temps, carburant, CO₂ (US-057, US-060).
class SavingsCard extends StatelessWidget {
  const SavingsCard({super.key, required this.savings, this.title});

  final Savings savings;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final white = Colors.white.withValues(alpha: .92);
    Widget cell(String value, String label) => SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTheme.weighted(22, 800, color: Colors.white)),
          Text(label, style: AppTheme.weighted(12, 600, color: white)),
        ],
      ),
    );
    return EcoCard(
      gradient: EcoGradients.green,
      decorated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🌍 ${title ?? l.tourSavingsTitle}',
            style: AppTheme.weighted(15, 700, color: Colors.white),
          ),
          const SizedBox(height: 10),
          if (!savings.isPositive)
            Text(l.tourNoSavings, style: AppTheme.weighted(14, 500, color: white))
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                cell(l.tourSavedKm(fmtKm(context, savings.km)), 'km'),
                if (savings.minutes >= 1) cell(l.tourSavedMin(savings.minutes.round()), 'min'),
                cell(l.dt(fmtDt(context, savings.dt)), l.tourFuel),
                cell(l.kg(fmtKg(context, savings.co2Kg)), l.tourCo2),
              ],
            ),
        ],
      ),
    );
  }
}
