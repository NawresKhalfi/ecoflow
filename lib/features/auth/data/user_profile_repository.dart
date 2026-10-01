import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/domain/notification_preferences.dart';
import '../domain/app_user.dart';
import '../domain/user_role.dart';
import '../domain/verification_status.dart';

/// Accès au profil `users/{uid}`.
abstract interface class UserProfileRepository {
  Stream<AppUser?> watch(String uid);
  Future<void> create(AppUser user);
  Future<void> updateDisplayName(String uid, String name);
  Future<void> updateLanguage(String uid, String code);
  Future<void> updateNotificationPreferences(String uid, NotificationPreferences prefs);
  Future<void> updateAiTrainingConsent(String uid, bool value);
}

class FirestoreUserProfileRepository implements UserProfileRepository {
  FirestoreUserProfileRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('users').doc(uid);

  static DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

  static AppUser? fromSnapshot(String uid, Map<String, dynamic>? m) {
    if (m == null || m['status'] == 'deleted') return null;
    final role = UserRole.fromName(m['role'] as String?);
    if (role == null) return null;
    return AppUser(
      uid: uid,
      displayName: m['displayName'] as String? ?? '',
      role: role,
      email: m['email'] as String?,
      phoneNumber: m['phoneNumber'] as String?,
      verificationStatus: VerificationStatus.fromName(m['verificationStatus'] as String?),
      rejectionReason: m['rejectionReason'] as String?,
      notificationPreferences: NotificationPreferences.fromMap(
        (m['notificationPreferences'] as Map?)?.cast<String, dynamic>(),
      ),
      languageCode: m['languageCode'] as String?,
      consentVersion: (m['consent'] as Map?)?['version'] as String?,
      consentAcceptedAt: _date((m['consent'] as Map?)?['acceptedAt']),
      createdAt: _date(m['createdAt']),
      aiTrainingConsent: m['aiTrainingConsent'] as bool? ?? false,
      blocked: m['status'] == 'blocked',
      blockedReason: m['blockedReason'] as String?,
      adminPermissions: (m['adminPermissions'] as List?)?.cast<String>().toSet(),
    );
  }

  @override
  Stream<AppUser?> watch(String uid) =>
      _doc(uid).snapshots().map((s) { debugPrint('DBGPROFILE $uid exists=${s.exists} cache=${s.metadata.isFromCache} data=${s.data()}'); return fromSnapshot(uid, s.data()); }).handleError((Object e) { debugPrint('DBGPROFILE error $e'); throw e; });

  @override
  Future<void> create(AppUser u) {
    if (!u.role.isSelfSelectable) {
      throw ArgumentError('Le rôle administrateur ne peut pas être choisi.');
    }
    return _doc(u.uid).set({
      'displayName': u.displayName.trim(),
      'role': u.role.name,
      'email': u.email,
      'phoneNumber': u.phoneNumber,
      'verificationStatus': VerificationStatus.initialFor(u.role.requiresVerification).name,
      'notificationPreferences': NotificationPreferences.defaults.toMap(),
      'languageCode': u.languageCode,
      'consent': {'version': u.consentVersion, 'acceptedAt': FieldValue.serverTimestamp()},
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateDisplayName(String uid, String name) =>
      _doc(uid).update({'displayName': name.trim()});

  @override
  Future<void> updateLanguage(String uid, String code) => _doc(uid).update({'languageCode': code});

  @override
  Future<void> updateNotificationPreferences(String uid, NotificationPreferences p) =>
      _doc(uid).update({'notificationPreferences': p.toMap()});

  @override
  Future<void> updateAiTrainingConsent(String uid, bool value) => _doc(
    uid,
  ).update({'aiTrainingConsent': value, 'aiTrainingConsentAt': FieldValue.serverTimestamp()});
}
