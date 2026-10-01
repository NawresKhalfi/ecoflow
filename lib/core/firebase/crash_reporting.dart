import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';

/// Activé en release ; en debug, seulement avec
/// `--dart-define=CRASHLYTICS_IN_DEBUG=true` (vérification sur appareil).
const _inDebug = bool.fromEnvironment('CRASHLYTICS_IN_DEBUG');

/// Rapports de plantage centralisés (US-131) : erreurs Flutter, erreurs
/// asynchrones non interceptées et plantages natifs remontent à Crashlytics,
/// qui alerte sur les nouvelles erreurs et les pics (console Firebase).
Future<void> setupCrashReporting() async {
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode || _inDebug);
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    crashlytics.recordFlutterError(details, fatal: false);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };
}

/// Contexte des rapports : identifiant pseudonyme (uid) et rôle, jamais de
/// nom ni d'e-mail (US-127).
final crashContextProvider = Provider<void>((ref) {
  final session = ref.watch(sessionProvider);
  final crashlytics = ref.watch(crashlyticsProvider);
  if (crashlytics == null) return;
  crashlytics.setUserIdentifier(session.authUser?.uid ?? '');
  crashlytics.setCustomKey('role', session.role?.name ?? 'none');
});

/// `null` sans Firebase initialisé (tests de widgets).
final crashlyticsProvider = Provider<FirebaseCrashlytics?>(
  (_) => Firebase.apps.isEmpty ? null : FirebaseCrashlytics.instance,
);

/// Outil de vérification de la chaîne de rapports, visible seulement si
/// l'app est lancée avec `CRASHLYTICS_IN_DEBUG` (jamais en production).
const crashlyticsTestTools = _inDebug;

/// Erreur non fatale de test, envoyée immédiatement.
Future<void> sendTestReport(FirebaseCrashlytics crashlytics) async {
  await crashlytics.log('EcoFlow : rapport de test déclenché depuis la supervision');
  await crashlytics.recordError(
    StateError('Test Crashlytics EcoFlow (non fatal)'),
    StackTrace.current,
    reason: 'vérification de la chaîne de rapports',
  );
  await crashlytics.sendUnsentReports();
}
