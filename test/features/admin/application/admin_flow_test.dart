import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/admin/application/admin_providers.dart';
import 'package:ecoflow/features/admin/domain/admin.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/auth/domain/user_role.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/service_zone.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late ProviderContainer c;

  AdminController ctrl() => c.read(adminControllerProvider.notifier);
  Future<List<Map<String, dynamic>>> audit() async =>
      (await db.collection('auditLog').get()).docs.map((d) => d.data()).toList();

  setUp(() async {
    db = FakeFirebaseFirestore();
    await db.doc('users/admin').set({'displayName': 'Sarra', 'role': 'admin', 'status': 'active'});
    await db.doc('users/leila').set({
      'displayName': 'Leila',
      'role': 'citizen',
      'status': 'active',
      'email': 'l@x.tn',
    });
    await db.doc('users/karim').set({
      'displayName': 'Karim',
      'role': 'collector',
      'status': 'active',
      'verificationStatus': 'pending',
    });
    await db.doc('users/karim/documents/nationalId').set({
      'fileName': 'cin.jpg',
      'status': 'notSubmitted',
    });
    await db.doc('users/green').set({
      'displayName': 'Green',
      'role': 'recycler',
      'status': 'active',
      'verificationStatus': 'notSubmitted',
    });
    await db.doc('companies/green').set({
      'legalName': 'GreenPlast',
      'status': 'pending',
      'taxId': '123',
    });
    c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: const AuthUser(
              uid: 'admin',
              phoneNumber: '+21622000001',
              providerIds: ['phone'],
            ),
          ),
        ),
        firestoreProvider.overrideWithValue(db),
      ],
    );
    c
      ..listen(currentProfileProvider, (_, _) {})
      ..listen(adminControllerProvider, (_, _) {});
    await pumpEventQueue();
  });

  AdminUserView view(String uid, UserRole role) =>
      AdminUserView(uid: uid, displayName: uid, role: role);

  test('block and reactivate, each traced in the audit log (US-106, US-114)', () async {
    await ctrl().setBlocked(
      view('leila', UserRole.citizen),
      blocked: true,
      reason: 'Fraude aux points',
    );
    var u = (await db.doc('users/leila').get()).data()!;
    expect((u['status'], u['blockedReason']), ('blocked', 'Fraude aux points'));
    await ctrl().setBlocked(view('leila', UserRole.citizen), blocked: false);
    u = (await db.doc('users/leila').get()).data()!;
    expect((u['status'], u['blockedReason']), ('active', null));
    final log = await audit();
    expect([
      for (final e in log) e['action'],
    ], unorderedEquals([AuditAction.block, AuditAction.unblock]));
    expect(log.first['actorName'], 'Sarra');
  });

  test('applications: approve a collector, reject a recycler with reason (US-107)', () async {
    final pending = await c.read(adminRepositoryProvider).pendingReviews();
    expect({for (final p in pending) p.uid}, {'karim', 'green'});
    final karim = pending.firstWhere((p) => p.uid == 'karim');
    expect(karim.documents.single.fileName, 'cin.jpg');
    await ctrl().review(karim, approve: true);
    expect((await db.doc('users/karim').get()).data()!['verificationStatus'], 'approved');
    expect((await db.doc('users/karim/documents/nationalId').get()).data()!['status'], 'approved');
    final green = pending.firstWhere((p) => p.uid == 'green');
    expect(await ctrl().review(green, approve: false), isFalse, reason: 'reason required');
    await ctrl().review(green, approve: false, reason: 'Matricule fiscal illisible');
    expect((await db.doc('companies/green').get()).data()!['status'], 'rejected');
    final notes = (await db.collection('notifications').get()).docs.map((d) => d.data());
    expect(
      notes.where((n) => n['type'] == 'accountReview').map((n) => n['toUid']),
      unorderedEquals(['karim', 'green']),
    );
  });

  test('super admin manages administrators but not itself (US-113)', () async {
    expect(await ctrl().setAdmin(view('admin', UserRole.admin), admin: false), isFalse);
    await ctrl().setAdmin(
      view('leila', UserRole.citizen),
      admin: true,
      permissions: {AdminPermission.disputes},
    );
    var u = (await db.doc('users/leila').get()).data()!;
    expect(u['role'], 'admin');
    expect(u['adminPermissions'], ['disputes']);
    await ctrl().setAdmin(view('leila', UserRole.admin), admin: false);
    u = (await db.doc('users/leila').get()).data()!;
    expect((u['role'], u['adminPermissions']), ('citizen', null));
  });

  test('dispute decision notifies the reporter (US-112)', () async {
    await db.doc('tickets/t1').set({
      'collectionId': 'col1',
      'reporterUid': 'leila',
      'reason': 'collectorAbsent',
      'description': 'Personne n’est venu',
      'status': 'open',
      'createdAt': DateTime(2026, 9, 30),
    });
    final d = (await c.read(adminRepositoryProvider).watchDisputes().first).single;
    expect(await ctrl().resolve(d, upheld: true, resolution: ''), isFalse);
    await ctrl().resolve(
      d,
      upheld: true,
      resolution: 'Collecteur averti, nouvelle collecte offerte',
    );
    final t = (await db.doc('tickets/t1').get()).data()!;
    expect((t['status'], t['resolvedBy']), ('resolved', 'admin'));
    final n = (await db.collection('notifications').get()).docs.single.data();
    expect((n['toUid'], n['type'], n['collectionId']), ('leila', 'disputeUpdate', 'col1'));
  });

  test('announcements and service zones (US-116, US-117)', () async {
    expect(await ctrl().announce('', 'x', const Segment()), isFalse);
    await ctrl().announce(
      'Nouvelle zone',
      'Monastir est desservie',
      const Segment(role: UserRole.collector),
    );
    final a = (await c.read(adminRepositoryProvider).watchAnnouncements().first).single;
    expect((a.title, a.segment.role), ('Nouvelle zone', UserRole.collector));
    await ctrl().saveZones([
      const ServiceZone(id: 'sousse', name: 'Sousse', center: GeoPoint(35.8, 10.6), radiusKm: 15),
      const ServiceZone(
        id: 'mahdia',
        name: 'Mahdia',
        center: GeoPoint(35.5, 11.06),
        radiusKm: 8,
        active: false,
      ),
    ]);
    await ctrl().saveZones([
      const ServiceZone(id: 'sousse', name: 'Sousse', center: GeoPoint(35.8, 10.6), radiusKm: 20),
    ]);
    final zones = (await db.doc('config/collection').get()).data()!['zones'] as Map;
    expect(zones.keys, ['sousse'], reason: 'removed zone disappears');
    expect((zones['sousse'] as Map)['radiusKm'], 20);
    expect([
      for (final e in await audit()) e['action'],
    ], containsAll([AuditAction.broadcast, AuditAction.zones]));
  });
}
