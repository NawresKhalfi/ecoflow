import 'package:ecoflow/core/localization/app_language.dart';
import 'package:ecoflow/core/localization/locale_resolver.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('picks the first supported device locale', () {
    expect(resolveLanguage(const [Locale('de'), Locale('ar', 'TN'), Locale('fr')]), AppLanguage.ar);
  });

  test('falls back to French when nothing matches', () {
    expect(resolveLanguage(const [Locale('de'), Locale('it')]), AppLanguage.fr);
    expect(resolveLanguage(const []), AppLanguage.fr);
  });

  test('only Arabic is right-to-left', () {
    expect(AppLanguage.values.where((l) => l.isRtl), [AppLanguage.ar]);
  });
}
