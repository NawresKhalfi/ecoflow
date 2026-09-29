import 'package:ecoflow/core/localization/app_language.dart';
import 'package:ecoflow/core/localization/language_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  test('defaults to the device language', () async {
    final c = await testContainer(overrides: [
      deviceLocalesProvider.overrideWithValue(const [Locale('en', 'US')]),
    ]);
    expect(c.read(languageControllerProvider), AppLanguage.en);
  });

  test('persists an explicit choice', () async {
    final c = await testContainer(overrides: [
      deviceLocalesProvider.overrideWithValue(const [Locale('en')]),
    ]);
    await c.read(languageControllerProvider.notifier).select(AppLanguage.ar);
    expect(c.read(languageControllerProvider), AppLanguage.ar);
    c.invalidate(languageControllerProvider);
    expect(c.read(languageControllerProvider), AppLanguage.ar);
  });
}
