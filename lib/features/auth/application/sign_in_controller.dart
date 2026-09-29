import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/auth_failure.dart';
import 'action_controller.dart';
import 'auth_providers.dart';

/// Connexion e-mail/mot de passe et Google, avec verrouillage local après
/// 5 échecs (US-002). La session persistante (jeton + refresh token) est
/// gérée par Firebase Auth.
class SignInController extends ActionController {
  Future<bool> signInWithEmail(String email, String password) => run(() async {
    final store = ref.read(loginAttemptsStoreProvider);
    final policy = ref.read(lockoutPolicyProvider);
    final now = ref.read(clockProvider)();
    final attempts = store.read(email);
    if (policy.isLocked(attempts, now)) {
      throw AuthFailure(AuthFailureCode.lockedOut, lockedUntil: attempts.lockedUntil);
    }
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(email, password);
      await store.clear(email);
    } on AuthFailure catch (f) {
      if (f.code != AuthFailureCode.wrongCredentials) rethrow;
      final next = policy.registerFailure(attempts, now);
      await store.write(email, next);
      if (policy.isLocked(next, now)) {
        throw AuthFailure(AuthFailureCode.lockedOut, lockedUntil: next.lockedUntil);
      }
      rethrow;
    }
  });

  /// Essais restants avant verrouillage pour cet e-mail.
  int remainingAttempts(String email) =>
      ref.read(lockoutPolicyProvider).remaining(ref.read(loginAttemptsStoreProvider).read(email));

  Future<bool> signInWithGoogle() => run(() => ref.read(authRepositoryProvider).signInWithGoogle());
}

final signInControllerProvider = NotifierProvider.autoDispose<SignInController, AsyncValue<void>>(
  SignInController.new,
);
