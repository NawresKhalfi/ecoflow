import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_preferences.dart';
import 'app_language.dart';
import 'locale_resolver.dart';

/// Locales du téléphone, surchargeable en test.
final deviceLocalesProvider = Provider<List<Locale>>(
  (ref) => WidgetsBinding.instance.platformDispatcher.locales,
);

/// Langue courante : choix explicite mémorisé, sinon locale du téléphone.
/// Le changement est appliqué à chaud (MaterialApp se reconstruit).
class LanguageController extends Notifier<AppLanguage> {
  static const _key = 'app.language';

  @override
  AppLanguage build() {
    final saved = ref.read(localPreferencesProvider).getString(_key);
    return AppLanguage.fromCode(saved) ??
        resolveLanguage(ref.read(deviceLocalesProvider));
  }

  Future<void> select(AppLanguage language) async {
    state = language;
    await ref.read(localPreferencesProvider).setString(_key, language.code);
  }
}

final languageControllerProvider =
    NotifierProvider<LanguageController, AppLanguage>(LanguageController.new);
