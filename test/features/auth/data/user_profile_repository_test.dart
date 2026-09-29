import 'package:ecoflow/features/auth/data/login_attempts_store.dart';
import 'package:ecoflow/features/auth/data/user_profile_repository.dart';
import 'package:ecoflow/features/auth/domain/app_user.dart';
import 'package:ecoflow/features/auth/domain/login_lockout_policy.dart';
import 'package:ecoflow/features/auth/domain/user_role.dart';
import 'package:ecoflow/features/auth/domain/verification_status.dart';
import 'package:ecoflow/features/profile/domain/notification_preferences.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FirestoreUserProfileRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = FirestoreUserProfileRepository(db);
  });

  test('creates a profile with consent and initial verification status', () async {
    await repo.create(const AppUser(
        uid: 'u1', displayName: ' Karim ', role: UserRole.collector, consentVersion: '2026-09'));
    final raw = (await db.doc('users/u1').get()).data()!;
    expect(raw['displayName'], 'Karim');
    expect(raw['role'], 'collector');
    expect(raw['verificationStatus'], 'notSubmitted');
    expect(raw['consent']['version'], '2026-09');
    expect(raw['status'], 'active');

    final user = await repo.watch('u1').first;
    expect(user!.role, UserRole.collector);
    expect(user.verificationStatus, VerificationStatus.notSubmitted);
    expect(user.notificationPreferences.isEnabled(NotificationCategory.points), isTrue);
  });

  test('refuses to create an admin profile', () {
    expect(() => repo.create(const AppUser(uid: 'x', displayName: 'X', role: UserRole.admin)),
        throwsArgumentError);
  });

  test('deleted profiles are treated as absent', () async {
    await db.doc('users/u2').set({'role': 'citizen', 'status': 'deleted'});
    expect(await repo.watch('u2').first, isNull);
  });

  test('updates notification preferences and language', () async {
    await repo.create(const AppUser(uid: 'u3', displayName: 'S', role: UserRole.citizen));
    await repo.updateNotificationPreferences(
        'u3', NotificationPreferences.defaults.toggle(NotificationCategory.marketplace, false));
    await repo.updateLanguage('u3', 'ar');
    final u = await repo.watch('u3').first;
    expect(u!.notificationPreferences.isEnabled(NotificationCategory.marketplace), isFalse);
    expect(u.languageCode, 'ar');
  });

  test('login attempts store round-trips per email', () async {
    final store = LoginAttemptsStore(await memoryPrefs());
    final until = DateTime(2026, 9, 29, 12);
    await store.write('A@b.tn', LoginAttempts(failures: 5, lockedUntil: until));
    expect(store.read(' a@b.tn').failures, 5);
    expect(store.read('a@b.tn').lockedUntil, until);
    await store.clear('a@b.tn');
    expect(store.read('a@b.tn').failures, 0);
  });
}
