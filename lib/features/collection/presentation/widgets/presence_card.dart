import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/collection_actions_controller.dart';

/// Interrupteur de disponibilité du collecteur vérifié (base de l'US-042).
class PresenceCard extends ConsumerWidget {
  const PresenceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final online = ref.watch(myPresenceProvider).value ?? false;
    final state = ref.watch(presenceControllerProvider);
    final fg = online ? Colors.white : context.eco.ink;
    return EcoCard(
      gradient: online ? EcoGradients.green : null,
      decorated: online,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📡 ${l.presenceTitle}', style: AppTheme.weighted(17, 800, color: fg)),
                      Text(
                        online ? '🟢 ${l.presenceOn}' : '⚪ ${l.presenceOff}',
                        style: AppTheme.weighted(14, 600, color: fg),
                      ),
                    ],
                  ),
                ),
                if (state.isLoading)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Switch(
                    value: online,
                    onChanged: (v) => ref.read(presenceControllerProvider.notifier).setOnline(v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.error is LocationRequired ? l.presenceNeedsLocation : l.presenceBody,
            style: AppTheme.weighted(
              13,
              500,
              color: online ? Colors.white.withValues(alpha: .9) : context.eco.muted,
            ),
          ),
        ],
      ),
    );
  }
}
