import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/collection_request.dart';

/// Frise de suivi (cf. `.tl` du prototype).
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.status});
  final CollectionStatus status;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [l.tlRequested, l.tlAssigned, l.stOnTheWay, l.tlHandedOver, l.stCompleted];
    final step = status.step;
    return Semantics(
      label: labels[step.clamp(0, 4)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 8,
                    decoration: BoxDecoration(
                      color: i <= step ? EcoColors.primaryBright : context.eco.line,
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ExcludeSemantics(
            child: Text(labels.join(' · '), style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
