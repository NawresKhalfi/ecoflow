/// Erreurs d'authentification typées, traduites dans l'UI.
enum AuthFailureCode {
  invalidEmail,
  weakPassword,
  emailInUse,
  wrongCredentials,
  userDisabled,
  tooManyRequests,
  lockedOut,
  invalidPhone,
  invalidCode,
  codeExpired,
  network,
  cancelled,
  providerUnavailable,
  requiresRecentLogin,
  unknown,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, {this.lockedUntil});

  final AuthFailureCode code;
  final DateTime? lockedUntil;

  @override
  String toString() => 'AuthFailure($code)';
}

/// Correspondance codes FirebaseAuthException → [AuthFailureCode].
AuthFailureCode mapFirebaseAuthCode(String code) => switch (code) {
      'invalid-email' => AuthFailureCode.invalidEmail,
      'weak-password' => AuthFailureCode.weakPassword,
      'email-already-in-use' || 'credential-already-in-use' => AuthFailureCode.emailInUse,
      'wrong-password' ||
      'user-not-found' ||
      'invalid-credential' ||
      'INVALID_LOGIN_CREDENTIALS' =>
        AuthFailureCode.wrongCredentials,
      'user-disabled' => AuthFailureCode.userDisabled,
      'too-many-requests' || 'quota-exceeded' => AuthFailureCode.tooManyRequests,
      'invalid-phone-number' || 'missing-phone-number' => AuthFailureCode.invalidPhone,
      'invalid-verification-code' || 'missing-verification-code' => AuthFailureCode.invalidCode,
      'session-expired' || 'code-expired' => AuthFailureCode.codeExpired,
      'network-request-failed' => AuthFailureCode.network,
      'popup-closed-by-user' || 'canceled' || 'cancelled' => AuthFailureCode.cancelled,
      'operation-not-allowed' || 'app-not-authorized' || 'configuration-not-found' =>
        AuthFailureCode.providerUnavailable,
      'requires-recent-login' => AuthFailureCode.requiresRecentLogin,
      _ => AuthFailureCode.unknown,
    };
