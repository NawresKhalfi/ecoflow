import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'action_controller.dart';
import 'auth_providers.dart';

/// Réinitialisation du mot de passe par lien e-mail (US-004).
class PasswordResetController extends ActionController {
  Future<bool> sendReset(String email) =>
      run(() => ref.read(authRepositoryProvider).sendPasswordReset(email));
}

final passwordResetControllerProvider =
    NotifierProvider.autoDispose<PasswordResetController, AsyncValue<void>>(
      PasswordResetController.new,
    );
