import 'package:ecoflow/core/router/route_guard.dart';
import 'package:ecoflow/core/router/routes.dart';
import 'package:ecoflow/features/auth/domain/app_user.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/auth/domain/session_state.dart';
import 'package:ecoflow/features/auth/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

SessionState ready(UserRole role) => SessionState(
      SessionStatus.ready,
      authUser: const AuthUser(uid: 'u'),
      profile: AppUser(uid: 'u', displayName: 'A', role: role),
    );

void main() {
  test('loading always shows the splash', () {
    expect(resolveRedirect(SessionState.loading, Routes.home), Routes.splash);
    expect(resolveRedirect(SessionState.loading, Routes.splash), isNull);
  });

  test('signed-out users only reach public pages', () {
    expect(resolveRedirect(SessionState.signedOut, Routes.signIn), isNull);
    expect(resolveRedirect(SessionState.signedOut, Routes.phone), isNull);
    expect(resolveRedirect(SessionState.signedOut, Routes.home), Routes.welcome);
    expect(resolveRedirect(SessionState.signedOut, Routes.splash), Routes.welcome);
  });

  test('privacy and language pages are always reachable', () {
    expect(resolveRedirect(SessionState.signedOut, Routes.privacy), isNull);
    expect(resolveRedirect(ready(UserRole.citizen), Routes.language), isNull);
  });

  test('unverified email is held on the verification page', () {
    const s = SessionState(SessionStatus.needsEmailVerification);
    expect(resolveRedirect(s, Routes.home), Routes.verifyEmail);
    expect(resolveRedirect(s, Routes.verifyEmail), isNull);
  });

  test('missing profile goes to profile completion', () {
    const s = SessionState(SessionStatus.needsProfile);
    expect(resolveRedirect(s, Routes.phone), Routes.completeProfile);
  });

  test('ready users leave auth pages for their space', () {
    expect(resolveRedirect(ready(UserRole.citizen), Routes.signIn), Routes.home);
    expect(resolveRedirect(ready(UserRole.citizen), Routes.profile), isNull);
  });

  test('role-specific pages are restricted to their role', () {
    expect(resolveRedirect(ready(UserRole.citizen), Routes.addressNew), isNull);
    expect(resolveRedirect(ready(UserRole.collector), Routes.addresses), Routes.home);
    expect(resolveRedirect(ready(UserRole.collector), Routes.documents), isNull);
    expect(resolveRedirect(ready(UserRole.citizen), Routes.documents), Routes.home);
    expect(resolveRedirect(ready(UserRole.recycler), Routes.company), isNull);
    expect(resolveRedirect(ready(UserRole.collector), Routes.company), Routes.home);
  });
}
