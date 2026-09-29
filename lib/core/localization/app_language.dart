import 'package:flutter/widgets.dart';

/// Langues supportées par EcoFlow. À garder en phase avec `lib/l10n/arb/`.
enum AppLanguage {
  fr('fr', 'Français', '🇫🇷'),
  ar('ar', 'العربية', '🇹🇳'),
  en('en', 'English', '🇬🇧');

  const AppLanguage(this.code, this.nativeName, this.flag);

  final String code;
  final String nativeName;
  final String flag;

  Locale get locale => Locale(code);
  bool get isRtl => this == AppLanguage.ar;

  static const fallback = AppLanguage.fr;

  static AppLanguage? fromCode(String? code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}
