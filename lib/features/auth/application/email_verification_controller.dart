import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'action_controller.dart';
import 'auth_providers.dart';

/// Écran « vérifie ton e-mail » : renvoi du lien et contrôle du statut.
class EmailVerificationController extends ActionController {
  bool lastCheckVerified = false;

  Future<bool> resend() => run(() => ref.read(authRepositoryProvider).sendEmailVerification());

  Future<bool> check() => run(() async {
        lastCheckVerified = await ref.read(authRepositoryProvider).reloadEmailVerified();
        // Relit l'utilisateur pour que la session voie emailVerified = true.
        if (lastCheckVerified) ref.invalidate(authStateProvider);
      });

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}

final emailVerificationControllerProvider =
    NotifierProvider.autoDispose<EmailVerificationController, AsyncValue<void>>(
        EmailVerificationController.new);
