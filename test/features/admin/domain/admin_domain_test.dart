import 'package:ecoflow/core/router/route_guard.dart';
import 'package:ecoflow/core/router/routes.dart';
import 'package:ecoflow/features/admin/domain/admin.dart';
import 'package:ecoflow/features/admin/domain/platform_stats.dart';
import 'package:ecoflow/features/auth/domain/app_user.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/auth/domain/session_state.dart';
import 'package:ecoflow/features/auth/domain/user_role.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:flutter_test/flutter_test.dart';

final t0 = DateTime(2026, 9, 1);

CollectionStat c(
  String id, {
  String status = 'completed',
  int day = 10,
  String? collector = 'k1',
  String citizen = 'c1',
  int acceptAfterMin = 30,
  int completeAfterH = 26,
  double estimated = 10,
  Map<RecyclableMaterial, double> kg = const {
    RecyclableMaterial.pet: 8,
    RecyclableMaterial.aluminium: 2,
  },
}) {
  final created = t0.add(Duration(days: day));
  return CollectionStat(
    id: id,
    status: status,
    zoneId: 'sousse',
    createdAt: created,
    citizenUid: citizen,
    collectorUid: collector,
    acceptedAt: collector == null ? null : created.add(Duration(minutes: acceptAfterMin)),
    completedAt: status == 'completed' ? created.add(Duration(hours: completeAfterH)) : null,
    estimatedKg: estimated,
    actualKg: status == 'completed' ? kg : const {},
  );
}

void main() {
  test('platform statistics: tonnes, CO₂, rates, delays, AI accuracy (US-109 to US-111)', () {
    final s = platformStats(
      [
        c('a'),
        c(
          'b',
          estimated: 12,
          kg: {RecyclableMaterial.glass: 10},
          acceptAfterMin: 90,
          completeAfterH: 2,
        ),
        c('x', status: 'cancelled', collector: null),
        c('y', status: 'noCollector', collector: null, citizen: 'c2'),
        c('old', day: -40),
      ],
      [
        (uid: 'c1', role: UserRole.citizen, createdAt: t0.add(const Duration(days: 3))),
        (uid: 'c2', role: UserRole.citizen, createdAt: DateTime(2025)),
        (uid: 'k1', role: UserRole.collector, createdAt: DateTime(2025)),
      ],
      t0,
      t0.add(const Duration(days: 30)),
    );
    expect(s.totalKg, 20, reason: 'old pickup outside the period');
    expect(s.tonnes, .02);
    expect(s.kgByMaterial[RecyclableMaterial.glass], 10);
    expect(s.co2Kg, closeTo(8 * 1.5 + 2 * 9 + 10 * .3, 1e-9));
    expect((s.requests, s.completed, s.cancelled, s.matched), (4, 2, 1, 2));
    expect(s.matchingRate, .5);
    expect(s.cancelRate, .25);
    expect(s.avgAcceptMinutes, 60);
    expect(s.avgCompletionHours, 14);
    expect(s.aiAccuracy, closeTo(1 - (0 + .2) / 2, 1e-9));
    expect(s.activeUsers, {UserRole.citizen: 2, UserRole.collector: 1});
    expect(s.newUsers, {UserRole.citizen: 1});
  });

  test('blocked account: dedicated session state and route (US-106)', () {
    const user = AuthUser(uid: 'u', phoneNumber: '+216', providerIds: ['phone']);
    const blocked = AppUser(
      uid: 'u',
      displayName: 'U',
      role: UserRole.citizen,
      blocked: true,
      blockedReason: 'Fraude',
    );
    final s = computeSession(
      authLoaded: true,
      authUser: user,
      profileLoaded: true,
      profile: blocked,
    );
    expect(s.status, SessionStatus.blocked);
    expect(resolveRedirect(s, Routes.home), Routes.blocked);
    expect(resolveRedirect(s, Routes.blocked), isNull);
    expect(resolveRedirect(s, Routes.privacy), isNull);
  });

  test('admin permissions: super admin vs delegated (US-113)', () {
    const superA = AppUser(uid: 'a', displayName: 'A', role: UserRole.admin);
    const delegated = AppUser(
      uid: 'b',
      displayName: 'B',
      role: UserRole.admin,
      adminPermissions: {AdminPermission.disputes},
    );
    const citizen = AppUser(uid: 'c', displayName: 'C', role: UserRole.citizen);
    expect((superA.isSuperAdmin, superA.can(AdminPermission.users)), (true, true));
    expect(
      (
        delegated.isSuperAdmin,
        delegated.can(AdminPermission.disputes),
        delegated.can(AdminPermission.users),
      ),
      (false, true, false),
    );
    expect(citizen.can(AdminPermission.disputes), isFalse);
  });

  test('announcement segments and user search (US-106, US-116)', () {
    const all = Segment();
    const collectorsSousse = Segment(role: UserRole.collector, zoneId: 'sousse');
    expect(all.matches(UserRole.citizen, {}), isTrue);
    expect(collectorsSousse.matches(UserRole.collector, {'sousse'}), isTrue);
    expect(collectorsSousse.matches(UserRole.collector, {'tunis'}), isFalse);
    expect(collectorsSousse.matches(UserRole.citizen, {'sousse'}), isFalse);
    const u = AdminUserView(
      uid: 'abc123',
      displayName: 'Leila Trabelsi',
      role: UserRole.citizen,
      email: 'leila@ecoflow.tn',
    );
    expect(
      [u.matches('trab'), u.matches('LEILA@'), u.matches('abc1'), u.matches('karim')],
      [true, true, true, false],
    );
  });
}
