import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/settings_controller.dart';
import '../../domain/notification_preferences.dart';

/// Préférences de notifications par catégorie (US-009).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    ref.watch(settingsControllerProvider); // garde le controller actif pendant l'écran
    final prefs =
        ref.watch(sessionProvider).profile?.notificationPreferences ??
        NotificationPreferences.defaults;
    final items = [
      (
        NotificationCategory.collectionStatus,
        '🚚',
        l.notifCollection,
        l.notifCollectionDesc,
        EcoGradients.coral,
      ),
      (NotificationCategory.points, '🏅', l.notifPoints, l.notifPointsDesc, EcoGradients.violet),
      (
        NotificationCategory.marketplace,
        '🔁',
        l.notifMarketplace,
        l.notifMarketplaceDesc,
        EcoGradients.sky,
      ),
    ];
    return LayeredPage(
      header: HeroHeader(
        title: l.notifTitle,
        subtitle: l.notifSubtitle,
        emoji: '🔔',
        gradient: EcoGradients.sun,
      ),
      children: [
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final (i, (cat, emoji, title, desc, gradient)) in items.indexed)
                MergeSemantics(
                  child: EcoListTile(
                    leading: EcoAvatar(text: emoji, gradient: gradient),
                    title: title,
                    subtitle: desc,
                    showDivider: i < items.length - 1,
                    trailing: Switch(
                      value: prefs.isEnabled(cat),
                      onChanged: (v) =>
                          ref.read(settingsControllerProvider.notifier).toggleNotification(cat, v),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
