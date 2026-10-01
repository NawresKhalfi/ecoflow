import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;

import '../../auth/domain/user_role.dart';
import '../../collection/domain/geo.dart';
import '../../collection/domain/service_zone.dart';
import '../../profile/domain/company_profile.dart';
import '../../recycler/domain/reception.dart';
import '../../scan/domain/waste_category.dart';
import '../../tracking/domain/app_notification.dart';
import '../domain/admin.dart';
import '../domain/platform_stats.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

/// Dossier professionnel à valider (US-107).
typedef PendingReview = ({
  String uid,
  String name,
  UserRole role,
  String detail,
  List<({String type, String fileName})> documents,
  DateTime? submittedAt,
});

/// Collecteur en ligne sur la carte de supervision.
typedef OnlineCollector = ({String uid, GeoPoint point, double capacityKg});

/// Administration et supervision (US-106 à US-117). Chaque action sensible
/// écrit une ligne `auditLog` dans le même batch (US-114).
class AdminRepository {
  AdminRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

  void _audit(
    WriteBatch b,
    ({String uid, String name}) actor,
    String action,
    String targetType,
    String targetId, [
    String details = '',
  ]) => b.set(_db.collection('auditLog').doc(), {
    'actorUid': actor.uid,
    'actorName': actor.name,
    'action': action,
    'targetType': targetType,
    'targetId': targetId,
    'details': details,
    'at': FieldValue.serverTimestamp(),
  });

  void _notify(
    WriteBatch b,
    String actor,
    String to,
    NotificationType type,
    String id,
    String preview,
  ) => b.set(_db.collection('notifications').doc(), {
    'toUid': to,
    'fromUid': actor,
    'type': type.name,
    'collectionId': id,
    'address': '',
    'preview': preview,
    'critical': false,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });

  // --- Comptes (US-106, US-113) --------------------------------------------

  AdminUserView _view(String uid, Map<String, dynamic> m) => AdminUserView(
    uid: uid,
    displayName: m['displayName'] as String? ?? '',
    role: UserRole.fromName(m['role'] as String?) ?? UserRole.citizen,
    email: m['email'] as String?,
    phone: m['phoneNumber'] as String?,
    status: m['status'] as String? ?? 'active',
    verificationStatus: m['verificationStatus'] as String?,
    blockedReason: m['blockedReason'] as String?,
    adminPermissions: (m['adminPermissions'] as List?)?.cast<String>().toSet(),
    createdAt: _date(m['createdAt']),
  );

  Stream<List<AdminUserView>> watchUsers() => _db
      .collection('users')
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) _view(d.id, d.data())]
              ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase())),
      );

  Future<void> setBlocked(
    ({String uid, String name}) actor,
    AdminUserView u, {
    required bool blocked,
    String reason = '',
  }) async {
    final b = _db.batch()
      ..update(_user(u.uid), {
        'status': blocked ? 'blocked' : 'active',
        'blockedReason': blocked ? reason.trim() : null,
      });
    _audit(
      b,
      actor,
      blocked ? AuditAction.block : AuditAction.unblock,
      'user',
      u.uid,
      reason.trim(),
    );
    await b.commit();
  }

  /// Promotion, rétrogradation, permissions (super-administrateur).
  Future<void> setAdmin(
    ({String uid, String name}) actor,
    AdminUserView u, {
    required bool admin,
    Set<String>? permissions,
  }) async {
    final b = _db.batch()
      ..update(_user(u.uid), {
        'role': admin ? UserRole.admin.name : UserRole.citizen.name,
        'adminPermissions': admin ? (permissions?.toList()?..sort()) : null,
      });
    final action = !admin
        ? AuditAction.demote
        : u.role == UserRole.admin
        ? AuditAction.permissions
        : AuditAction.promote;
    _audit(b, actor, action, 'user', u.uid, admin ? (permissions?.join(', ') ?? 'super') : '');
    await b.commit();
  }

  // --- Validations (US-107) ------------------------------------------------

  Future<List<PendingReview>> pendingReviews() async {
    final collectors = await _db
        .collection('users')
        .where('verificationStatus', isEqualTo: 'pending')
        .get();
    final companies = await _db.collection('companies').where('status', isEqualTo: 'pending').get();
    final out = <PendingReview>[];
    for (final d in collectors.docs.where((d) => d.data()['role'] == 'collector')) {
      final docs = await _user(d.id).collection('documents').get();
      out.add((
        uid: d.id,
        name: d.data()['displayName'] as String? ?? '',
        role: UserRole.collector,
        detail: d.data()['email'] as String? ?? d.data()['phoneNumber'] as String? ?? '',
        documents: [
          for (final x in docs.docs) (type: x.id, fileName: x.data()['fileName'] as String? ?? ''),
        ],
        submittedAt: _date(d.data()['submittedAt']),
      ));
    }
    for (final d in companies.docs) {
      final m = d.data();
      out.add((
        uid: d.id,
        name: m['legalName'] as String? ?? '',
        role: UserRole.recycler,
        detail: [m['taxId'], m['city'], m['contactPhone']].whereType<String>().join(' · '),
        documents: const [],
        submittedAt: _date(m['submittedAt']),
      ));
    }
    return out;
  }

  Future<Uint8List?> documentFile(String uid, String type) async {
    final d = (await _user(uid).collection('documentFiles').doc(type).get()).data();
    final data = d?['data'] as String?;
    return data == null ? null : base64Decode(data);
  }

  Future<void> review(
    ({String uid, String name}) actor,
    PendingReview r, {
    required bool approve,
    String reason = '',
  }) async {
    final status = approve ? 'approved' : 'rejected';
    final b = _db.batch()
      ..update(_user(r.uid), {
        'verificationStatus': status,
        'rejectionReason': approve ? null : reason.trim(),
        'reviewedBy': actor.uid,
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    if (r.role == UserRole.recycler) {
      b.update(_db.collection('companies').doc(r.uid), {
        'status': status,
        'rejectionReason': approve ? null : reason.trim(),
      });
    }
    for (final d in r.documents) {
      b.update(_user(r.uid).collection('documents').doc(d.type), {
        'status': status,
        'rejectionReason': approve ? null : reason.trim(),
      });
    }
    _audit(
      b,
      actor,
      approve ? AuditAction.approve : AuditAction.reject,
      r.role.name,
      r.uid,
      reason.trim(),
    );
    _notify(b, actor.uid, r.uid, NotificationType.accountReview, r.uid, status);
    await b.commit();
  }

  // --- Supervision : collectes et indicateurs (US-108 à US-111) ------------

  CollectionStat _stat(
    String id,
    Map<String, dynamic> m,
    Map<String, dynamic>? est,
    List<WasteCategory> catalog,
  ) {
    final kg = <RecyclableMaterial, double>{};
    for (final e in (est?['actualKg'] as Map? ?? const {}).entries) {
      final mat = materialForCategory('${e.key}', catalog);
      kg[mat] = (kg[mat] ?? 0) + (e.value as num).toDouble();
    }
    final place = m['place'] as Map?;
    return CollectionStat(
      id: id,
      status: m['status'] as String? ?? '',
      zoneId: place?['zoneId'] as String? ?? '',
      createdAt: _date(m['createdAt']) ?? DateTime(2000),
      citizenUid: m['citizenUid'] as String?,
      collectorUid: m['collectorUid'] as String?,
      point: GeoPoint.fromMap(place?['point']),
      acceptedAt: _date(m['acceptedAt']),
      completedAt: _date(m['completedAt']),
      estimatedKg:
          (m['estimatedKg'] as num?)?.toDouble() ?? (est?['totalKg'] as num?)?.toDouble() ?? 0,
      actualKg: kg,
      cancelledBy: m['cancelledBy'] as String?,
    );
  }

  Stream<List<CollectionStat>> watchLive(List<WasteCategory> catalog) => _db
      .collection('collections')
      .where('status', whereIn: liveStatuses)
      .snapshots()
      .map((s) => [for (final d in s.docs) _stat(d.id, d.data(), null, catalog)]);

  Stream<List<OnlineCollector>> watchOnlineCollectors() => _db
      .collection('collectorPresence')
      .where('online', isEqualTo: true)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (GeoPoint.fromMap(d.data()['point']) case final p?)
              (uid: d.id, point: p, capacityKg: (d.data()['capacityKg'] as num?)?.toDouble() ?? 0),
        ],
      );

  /// Toutes les collectes et leurs pesées (indicateurs).
  Future<List<CollectionStat>> allCollections(List<WasteCategory> catalog) async {
    final docs = (await _db.collection('collections').get()).docs;
    final codes = [
      for (final d in docs)
        if (d.data()['status'] == 'completed' && d.data()['estimateCode'] is String)
          d.data()['estimateCode'] as String,
    ];
    final est = <String, Map<String, dynamic>>{};
    for (var i = 0; i < codes.length; i += 30) {
      final q = await _db
          .collection('estimates')
          .where(
            FieldPath.documentId,
            whereIn: codes.sublist(i, i + 30 > codes.length ? codes.length : i + 30),
          )
          .get();
      for (final d in q.docs) {
        est[d.id] = d.data();
      }
    }
    return [for (final d in docs) _stat(d.id, d.data(), est[d.data()['estimateCode']], catalog)];
  }

  Future<List<UserStat>> userStats() async => [
    for (final d in (await _db.collection('users').get()).docs)
      if (UserRole.fromName(d.data()['role'] as String?) case final r?)
        (uid: d.id, role: r, createdAt: _date(d.data()['createdAt'])),
  ];

  /// Temps d'analyse des derniers scans (US-124).
  Future<List<ScanTiming>> scanTimings() async => [
    for (final d
        in (await _db.collection('scans').orderBy('createdAt', descending: true).limit(1000).get())
            .docs)
      if (d.data()['inferenceMs'] case final num ms)
        (at: _date(d.data()['createdAt']), ms: ms.toInt()),
  ];

  // --- Litiges (US-112) ----------------------------------------------------

  Dispute _dispute(String id, Map<String, dynamic> m) => Dispute(
    id: id,
    collectionId: m['collectionId'] as String? ?? '',
    reporterUid: m['reporterUid'] as String? ?? '',
    reporterRole: m['reporterRole'] as String? ?? 'citizen',
    reason: m['reason'] as String? ?? '',
    description: m['description'] as String? ?? '',
    photoCount: (m['photoCount'] as num?)?.toInt() ?? 0,
    status:
        DisputeStatus.values.where((s) => s.name == m['status']).firstOrNull ?? DisputeStatus.open,
    resolution: m['resolution'] as String? ?? '',
    createdAt: _date(m['createdAt']),
    resolvedAt: _date(m['resolvedAt']),
  );

  Stream<List<Dispute>> watchDisputes() => _db
      .collection('tickets')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs) _dispute(d.id, d.data()),
        ]..sort((a, b) => (a.createdAt ?? DateTime(3000)).compareTo(b.createdAt ?? DateTime(3000))),
      );

  Future<List<Uint8List>> disputePhotos(String id) async => [
    for (final d in (await _db.collection('tickets').doc(id).collection('photos').get()).docs)
      if (d.data()['data'] case final String b64) base64Decode(b64),
  ];

  Future<void> resolveDispute(
    ({String uid, String name}) actor,
    Dispute d, {
    required bool upheld,
    required String resolution,
  }) async {
    final b = _db.batch()
      ..update(_db.collection('tickets').doc(d.id), {
        'status': (upheld ? DisputeStatus.resolved : DisputeStatus.rejected).name,
        'resolution': resolution.trim(),
        'resolvedBy': actor.uid,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    _audit(b, actor, AuditAction.dispute, 'ticket', d.id, resolution.trim());
    _notify(
      b,
      actor.uid,
      d.reporterUid,
      NotificationType.disputeUpdate,
      d.collectionId,
      resolution.trim(),
    );
    await b.commit();
  }

  // --- Journal, annonces, zones (US-114, US-116, US-117) -------------------

  Stream<List<AuditEntry>> watchAudit() => _db
      .collection('auditLog')
      .orderBy('at', descending: true)
      .limit(300)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            AuditEntry(
              id: d.id,
              actorUid: d.data()['actorUid'] as String? ?? '',
              actorName: d.data()['actorName'] as String? ?? '',
              action: d.data()['action'] as String? ?? '',
              targetType: d.data()['targetType'] as String? ?? '',
              targetId: d.data()['targetId'] as String? ?? '',
              details: d.data()['details'] as String? ?? '',
              at: _date(d.data()['at']),
            ),
        ],
      );

  Future<void> announce(
    ({String uid, String name}) actor,
    String title,
    String body,
    Segment s,
  ) async {
    final ref = _db.collection('announcements').doc();
    final b = _db.batch()
      ..set(ref, {
        'title': title.trim(),
        'body': body.trim(),
        'role': s.role?.name,
        'zoneId': s.zoneId,
        'by': actor.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    _audit(
      b,
      actor,
      AuditAction.broadcast,
      'announcement',
      ref.id,
      '${s.role?.name ?? 'all'} · ${s.zoneId ?? 'all'}',
    );
    await b.commit();
  }

  Stream<List<Announcement>> watchAnnouncements() => _db
      .collection('announcements')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            Announcement(
              id: d.id,
              title: d.data()['title'] as String? ?? '',
              body: d.data()['body'] as String? ?? '',
              segment: Segment(
                role: UserRole.fromName(d.data()['role'] as String?),
                zoneId: d.data()['zoneId'] as String?,
              ),
              createdAt: _date(d.data()['createdAt']),
            ),
        ],
      );

  Future<void> saveZones(({String uid, String name}) actor, List<ServiceZone> zones) async {
    final b = _db.batch()
      ..set(_db.collection('config').doc('collection'), {
        'zones': {for (final z in zones) z.id: z.toMap()},
        // Champ remplacé en entier : une zone supprimée disparaît.
      }, SetOptions(mergeFields: ['zones']));
    _audit(b, actor, AuditAction.zones, 'config', 'collection', zones.map((z) => z.id).join(', '));
    await b.commit();
  }
}
