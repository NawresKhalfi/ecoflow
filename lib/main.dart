import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/firebase/crash_reporting.dart';
import 'core/firebase/emulators.dart';
import 'core/storage/local_preferences.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await connectFirebaseEmulators();
  await setupCrashReporting();
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [localPreferencesProvider.overrideWithValue(LocalPreferences(prefs))],
      child: const EcoFlowApp(),
    ),
  );
}
