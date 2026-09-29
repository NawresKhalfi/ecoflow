import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/language_controller.dart';
import '../domain/app_user.dart';
import '../domain/auth_failure.dart';
import '../domain/user_role.dart';
import 'action_controller.dart';
import 'auth_providers.dart';

/// Inscription e-mail (US-001, US-003) et complétion de profil après une
/// connexion par téléphone ou Google. Aucune donnée n'est écrite dans
/// Firebase sans consentement explicite.
class SignUpController extends ActionController {
  Future<bool> signUpWithEmail({
    required String displayName,
    required String email,
    required String password,
    required UserRole role,
    required bool consent,
  }) =>
      run(() async {
        _checkInputs(role, consent);
        final auth = ref.read(authRepositoryProvider);
        await auth.signUpWithEmail(email, password, displayName);
        await _createProfile(displayName, role, email: email.trim());
      });

  /// Crée le profil de l'utilisateur déjà authentifié (téléphone / Google).
  Future<bool> completeProfile({
    required String displayName,
    required UserRole role,
    required bool consent,
  }) =>
      run(() async {
        _checkInputs(role, consent);
        final user = ref.read(authRepositoryProvider).currentUser;
        await _createProfile(displayName, role,
            email: user?.email, phone: user?.phoneNumber);
      });

  void _checkInputs(UserRole role, bool consent) {
    if (!role.isSelfSelectable) throw ArgumentError('admin role is not selectable');
    if (!consent) throw const ConsentRequired();
  }

  Future<void> _createProfile(String name, UserRole role,
      {String? email, String? phone}) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) throw const AuthFailure(AuthFailureCode.unknown);
    await ref.read(userProfileRepositoryProvider).create(AppUser(
          uid: user.uid,
          displayName: name,
          role: role,
          email: email,
          phoneNumber: phone,
          languageCode: ref.read(languageControllerProvider).code,
          consentVersion: currentConsentVersion,
        ));
  }
}

/// Levée quand l'utilisateur n'a pas accepté la politique de confidentialité.
class ConsentRequired implements Exception {
  const ConsentRequired();
}

final signUpControllerProvider =
    NotifierProvider.autoDispose<SignUpController, AsyncValue<void>>(SignUpController.new);
