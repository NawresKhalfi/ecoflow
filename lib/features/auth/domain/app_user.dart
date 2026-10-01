import '../../profile/domain/notification_preferences.dart';
import 'user_role.dart';
import 'verification_status.dart';

/// Version de la politique de confidentialité acceptée à l'inscription.
const currentConsentVersion = '2026-09';

/// Profil EcoFlow stocké dans `users/{uid}`.
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.role,
    this.email,
    this.phoneNumber,
    this.verificationStatus = VerificationStatus.notRequired,
    this.rejectionReason,
    this.notificationPreferences = NotificationPreferences.defaults,
    this.languageCode,
    this.consentVersion,
    this.consentAcceptedAt,
    this.createdAt,
    this.aiTrainingConsent = false,
    this.blocked = false,
    this.blockedReason,
    this.adminPermissions,
  });

  final String uid;
  final String displayName;
  final UserRole role;
  final String? email;
  final String? phoneNumber;
  final VerificationStatus verificationStatus;
  final String? rejectionReason;
  final NotificationPreferences notificationPreferences;
  final String? languageCode;
  final String? consentVersion;
  final DateTime? consentAcceptedAt;
  final DateTime? createdAt;

  /// Accepte que ses photos corrigées servent à améliorer l'IA (US-020).
  final bool aiTrainingConsent;

  /// Compte bloqué par l'administration (US-106).
  final bool blocked;
  final String? blockedReason;

  /// Permissions d'un administrateur (US-113) ; `null` : super-administrateur
  /// (tous les droits, y compris la gestion des administrateurs).
  final Set<String>? adminPermissions;

  bool get isSuperAdmin => role == UserRole.admin && adminPermissions == null;

  bool can(String permission) =>
      role == UserRole.admin && (adminPermissions == null || adminPermissions!.contains(permission));

  String get firstName => displayName.trim().split(RegExp(r'\s+')).first;

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  AppUser copyWith({
    String? displayName,
    VerificationStatus? verificationStatus,
    NotificationPreferences? notificationPreferences,
    String? languageCode,
    bool? aiTrainingConsent,
  }) => AppUser(
    uid: uid,
    displayName: displayName ?? this.displayName,
    role: role,
    email: email,
    phoneNumber: phoneNumber,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    rejectionReason: rejectionReason,
    notificationPreferences: notificationPreferences ?? this.notificationPreferences,
    languageCode: languageCode ?? this.languageCode,
    consentVersion: consentVersion,
    consentAcceptedAt: consentAcceptedAt,
    createdAt: createdAt,
  );
}
