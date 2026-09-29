import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/language_controller.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/notification_preferences.dart';
import 'profile_providers.dart';

/// Nom affiché, langue (US-008) et préférences de notifications (US-009).
class SettingsController extends ActionController {
  Future<bool> updateDisplayName(String name) =>
      run(() => ref.read(userProfileRepositoryProvider).updateDisplayName(requireUid(ref), name));

  /// Changement à chaud ; synchronisé avec le profil si connecté.
  Future<void> selectLanguage(AppLanguage language) async {
    // Dépendances lues avant l'await : le controller peut être libéré ensuite.
    final uid = ref.read(currentUidProvider);
    final hasProfile = ref.read(currentProfileProvider).value != null;
    final profiles = ref.read(userProfileRepositoryProvider);
    await ref.read(languageControllerProvider.notifier).select(language);
    if (uid != null && hasProfile) await profiles.updateLanguage(uid, language.code);
  }

  Future<bool> toggleNotification(NotificationCategory c, bool value) => run(() async {
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) return;
    await ref
        .read(userProfileRepositoryProvider)
        .updateNotificationPreferences(
          profile.uid,
          profile.notificationPreferences.toggle(c, value),
        );
  });

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}

final settingsControllerProvider =
    NotifierProvider.autoDispose<SettingsController, AsyncValue<void>>(SettingsController.new);
