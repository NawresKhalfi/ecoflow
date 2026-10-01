import '../../auth/domain/user_role.dart';

/// Permissions d'un administrateur délégué (US-113). Un administrateur sans
/// liste est super-administrateur : tous les droits, dont la gestion des
/// autres administrateurs.
abstract final class AdminPermission {
  static const users = 'users';
  static const verifications = 'verifications';
  static const disputes = 'disputes';
  static const broadcast = 'broadcast';
  static const zones = 'zones';
  static const audit = 'audit';
  static const market = 'market';

  static const all = [users, verifications, disputes, broadcast, zones, audit, market];
}

/// Action sensible tracée : `auditLog/{id}` (US-114), en ajout seul.
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.action,
    required this.targetType,
    required this.targetId,
    this.details = '',
    this.at,
  });

  final String id;
  final String actorUid;
  final String actorName;
  final String action;
  final String targetType;
  final String targetId;
  final String details;
  final DateTime? at;
}

/// Types d'actions tracées.
abstract final class AuditAction {
  static const block = 'user.block';
  static const unblock = 'user.unblock';
  static const approve = 'verification.approve';
  static const reject = 'verification.reject';
  static const permissions = 'admin.permissions';
  static const promote = 'admin.promote';
  static const demote = 'admin.demote';
  static const dispute = 'dispute.resolve';
  static const broadcast = 'announcement.send';
  static const zones = 'zones.update';
}

/// Segment visé par une annonce (US-116).
class Segment {
  const Segment({this.role, this.zoneId});
  final UserRole? role;
  final String? zoneId;

  /// Un utilisateur sans zone connue reçoit les annonces sans zone.
  bool matches(UserRole r, Set<String> zones) =>
      (role == null || role == r) && (zoneId == null || zones.contains(zoneId));
}

/// Annonce à la communauté : `announcements/{id}`.
class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.segment,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final Segment segment;
  final DateTime? createdAt;
}

const maxAnnouncementTitle = 80;
const maxAnnouncementBody = 500;

enum DisputeStatus { open, resolved, rejected }

/// Litige ou signalement d'une collecte : `tickets/{id}` (US-112).
class Dispute {
  const Dispute({
    required this.id,
    required this.collectionId,
    required this.reporterUid,
    required this.reason,
    required this.description,
    this.reporterRole = 'citizen',
    this.photoCount = 0,
    this.status = DisputeStatus.open,
    this.resolution = '',
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String collectionId;
  final String reporterUid;
  final String reporterRole;
  final String reason;
  final String description;
  final int photoCount;
  final DisputeStatus status;
  final String resolution;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  /// Âge du litige, pour prioriser les plus anciens.
  Duration age(DateTime now) => now.difference(createdAt ?? now);
}

/// Utilisateur vu par l'administration (US-106).
class AdminUserView {
  const AdminUserView({
    required this.uid,
    required this.displayName,
    required this.role,
    this.email,
    this.phone,
    this.status = 'active',
    this.verificationStatus,
    this.blockedReason,
    this.adminPermissions,
    this.createdAt,
  });

  final String uid;
  final String displayName;
  final UserRole role;
  final String? email;
  final String? phone;
  final String status;
  final String? verificationStatus;
  final String? blockedReason;
  final Set<String>? adminPermissions;
  final DateTime? createdAt;

  bool get blocked => status == 'blocked';
  bool get isSuperAdmin => role == UserRole.admin && adminPermissions == null;

  /// Recherche par nom, e-mail, téléphone ou identifiant.
  bool matches(String q) {
    final t = q.trim().toLowerCase();
    if (t.isEmpty) return true;
    return [displayName, email ?? '', phone ?? '', uid].any((v) => v.toLowerCase().contains(t));
  }
}
