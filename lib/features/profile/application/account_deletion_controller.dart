import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import 'profile_providers.dart';

/// Suppression du compte en 2 étapes (US-010) : confirmation explicite puis
/// ré-authentification, anonymisation des données et suppression Auth.
class AccountDeletionController extends ActionController {
  static const confirmationWord = 'SUPPRIMER';

  /// Étape 1 : l'utilisateur doit saisir le mot de confirmation.
  bool isConfirmationValid(String typed) =>
      typed.trim().toUpperCase() == confirmationWord;

  /// Étape 2. [password] est requis pour les comptes e-mail.
  Future<bool> deleteAccount({String? password}) => run(() async {
        final auth = ref.read(authRepositoryProvider);
        final user = auth.currentUser;
        if (user == null) return;
        // Avant toute anonymisation, pour ne pas laisser un compte à moitié supprimé.
        await auth.ensureRecentLogin(password: password);
        await ref
            .read(accountDeletionRepositoryProvider)
            .anonymize(user.uid, ref.read(clockProvider)());
        await auth.deleteCurrentUser();
        await auth.signOut();
      });
}

final accountDeletionControllerProvider =
    NotifierProvider.autoDispose<AccountDeletionController, AsyncValue<void>>(
        AccountDeletionController.new);
