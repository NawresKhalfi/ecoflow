import '../../../core/storage/local_preferences.dart';
import '../domain/login_lockout_policy.dart';

/// Mémorise localement les échecs de connexion par e-mail (US-002).
class LoginAttemptsStore {
  LoginAttemptsStore(this._prefs);

  final LocalPreferences _prefs;

  String _key(String email) => 'auth.attempts.${email.trim().toLowerCase()}';

  LoginAttempts read(String email) {
    final raw = _prefs.getString(_key(email));
    if (raw == null) return LoginAttempts.none;
    final parts = raw.split('|');
    final until = int.tryParse(parts.length > 1 ? parts[1] : '');
    return LoginAttempts(
      failures: int.tryParse(parts[0]) ?? 0,
      lockedUntil: until == null ? null : DateTime.fromMillisecondsSinceEpoch(until),
    );
  }

  Future<void> write(String email, LoginAttempts a) =>
      _prefs.setString(_key(email), '${a.failures}|${a.lockedUntil?.millisecondsSinceEpoch ?? ''}');

  Future<void> clear(String email) => _prefs.remove(_key(email));
}
