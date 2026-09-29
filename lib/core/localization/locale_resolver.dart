import 'package:flutter/widgets.dart';

import 'app_language.dart';

/// Déduit la langue de l'application à partir des locales du téléphone
/// (ordre de préférence) ; français par défaut.
AppLanguage resolveLanguage(List<Locale> deviceLocales) {
  for (final locale in deviceLocales) {
    final match = AppLanguage.fromCode(locale.languageCode.toLowerCase());
    if (match != null) return match;
  }
  return AppLanguage.fallback;
}
