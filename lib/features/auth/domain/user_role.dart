/// Rôles de la plateforme. Le rôle détermine l'espace (navigation) affiché.
enum UserRole {
  citizen,
  collector,
  recycler,
  admin;

  /// Un administrateur ne peut jamais être choisi à l'inscription (US-003).
  bool get isSelfSelectable => this != UserRole.admin;

  /// Les professionnels doivent être vérifiés avant d'exercer (US-006/007).
  bool get requiresVerification => this == UserRole.collector || this == UserRole.recycler;

  static List<UserRole> get selectable => values.where((r) => r.isSelfSelectable).toList();

  static UserRole? fromName(String? name) {
    for (final r in values) {
      if (r.name == name) return r;
    }
    return null;
  }
}
