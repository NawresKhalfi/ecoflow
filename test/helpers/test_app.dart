import 'package:ecoflow/core/localization/app_language.dart';
import 'package:ecoflow/core/localization/l10n.dart';
import 'package:ecoflow/core/storage/local_preferences.dart';
import 'package:ecoflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalPreferences> memoryPrefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return LocalPreferences(await SharedPreferences.getInstance());
}

/// Conteneur Riverpod de test avec préférences en mémoire.
Future<ProviderContainer> testContainer({List<Override> overrides = const []}) async {
  final prefs = await memoryPrefs();
  final c = ProviderContainer.test(
    overrides: [localPreferencesProvider.overrideWithValue(prefs), ...overrides],
    retry: (_, _) => null,
  );
  return c;
}

/// Monte un écran avec thème, localisations et surcharges Riverpod.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Locale locale = const Locale('fr'),
  Size size = const Size(400, 900),
}) async {
  tester.view.physicalSize = size * 1.0;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final prefs = await memoryPrefs();
  await tester.pumpWidget(ProviderScope(
    overrides: [localPreferencesProvider.overrideWithValue(prefs), ...overrides],
    retry: (_, _) => null,
    child: MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: [for (final l in AppLanguage.values) l.locale],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: screen,
    ),
  ));
  await settle(tester);
}

/// Laisse passer les animations d'entrée (sans attendre les spinners).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}
