/// Utilisateur authentifié (vue indépendante de Firebase).
class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.phoneNumber,
    this.displayName,
    this.emailVerified = false,
    this.providerIds = const [],
  });

  final String uid;
  final String? email;
  final String? phoneNumber;
  final String? displayName;
  final bool emailVerified;
  final List<String> providerIds;

  bool get usesPassword => providerIds.contains('password');

  /// Seuls les comptes e-mail/mot de passe doivent confirmer leur adresse
  /// (Google et téléphone sont déjà vérifiés par le fournisseur).
  bool get needsEmailVerification => usesPassword && !emailVerified;
}
