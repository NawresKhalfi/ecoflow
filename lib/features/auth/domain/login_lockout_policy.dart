/// Compteur d'échecs de connexion pour un identifiant donné.
class LoginAttempts {
  const LoginAttempts({this.failures = 0, this.lockedUntil});

  final int failures;
  final DateTime? lockedUntil;

  static const none = LoginAttempts();
}

/// Verrouillage après 5 échecs consécutifs (US-002), pendant 15 minutes.
class LoginLockoutPolicy {
  const LoginLockoutPolicy({
    this.maxFailures = 5,
    this.lockDuration = const Duration(minutes: 15),
  });

  final int maxFailures;
  final Duration lockDuration;

  bool isLocked(LoginAttempts a, DateTime now) =>
      a.lockedUntil != null && now.isBefore(a.lockedUntil!);

  /// Nombre d'essais restants avant verrouillage.
  int remaining(LoginAttempts a) => (maxFailures - a.failures).clamp(0, maxFailures);

  LoginAttempts registerFailure(LoginAttempts a, DateTime now) {
    // Un verrou expiré repart de zéro.
    final base = a.lockedUntil != null && !isLocked(a, now) ? LoginAttempts.none : a;
    final failures = base.failures + 1;
    return LoginAttempts(
      failures: failures,
      lockedUntil: failures >= maxFailures ? now.add(lockDuration) : null,
    );
  }
}
