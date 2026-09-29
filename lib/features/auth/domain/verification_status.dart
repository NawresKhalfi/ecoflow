/// Statut de vérification d'un professionnel (collecteur / recycleur).
enum VerificationStatus {
  notRequired,
  notSubmitted,
  pending,
  approved,
  rejected;

  static VerificationStatus fromName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return VerificationStatus.notRequired;
  }

  static VerificationStatus initialFor(bool requiresVerification) =>
      requiresVerification ? notSubmitted : notRequired;

  /// Le professionnel peut (re)soumettre son dossier.
  bool get canSubmit => this == notSubmitted || this == rejected;
}
