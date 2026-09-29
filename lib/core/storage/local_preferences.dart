import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper fin autour de [SharedPreferences]. Chaque feature construit son
/// propre « local store » typé au-dessus plutôt que de manipuler des clés
/// brutes partout.
class LocalPreferences {
  LocalPreferences(this._prefs);

  final SharedPreferences _prefs;

  String? getString(String key) => _prefs.getString(key);
  int? getInt(String key) => _prefs.getInt(key);
  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setString(String key, String value) => _prefs.setString(key, value);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Surchargé dans `main.dart` avec l'instance réelle chargée avant `runApp`.
final localPreferencesProvider = Provider<LocalPreferences>(
  (ref) => throw UnimplementedError('localPreferencesProvider must be overridden'),
);
