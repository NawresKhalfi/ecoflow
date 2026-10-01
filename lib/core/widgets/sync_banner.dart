import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase/offline_write.dart';
import '../localization/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'eco_widgets.dart';

/// Bandeau hors ligne / synchronisation (US-126), posé au-dessus des écrans
/// de l'espace connecté. Un refus du serveur à la synchronisation (conflit)
/// est signalé par un message.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.listen(syncTrackerProvider.select((s) => s.conflicts), (prev, next) {
      if (next > (prev ?? 0)) showEcoToast(context, '⚠️ ${l.syncConflict}');
    });
    final offline = ref.watch(offlineProvider).value ?? false;
    final pending = ref.watch(syncTrackerProvider).pending;
    final visible = offline || pending > 0;
    final text = offline
        ? (pending > 0 ? l.syncOfflinePending(pending) : l.syncOffline)
        : l.syncSending(pending);
    return IgnorePointer(
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 250),
        offset: visible ? Offset.zero : const Offset(0, -1.5),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 250),
          opacity: visible ? 1 : 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Semantics(
                liveRegion: true,
                label: visible ? text : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: offline ? const Color(0xFF3A2B00) : EcoColors.skyDeep,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: context.eco.softShadow,
                  ),
                  child: Row(
                    children: [
                      Text(offline ? '📴' : '🔄', style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(text, style: AppTheme.weighted(13, 600, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
