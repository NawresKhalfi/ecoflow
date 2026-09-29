import 'package:ecoflow/features/auth/domain/app_user.dart';
import 'package:ecoflow/features/auth/domain/auth_failure.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/auth/domain/session_state.dart';
import 'package:ecoflow/features/auth/domain/user_role.dart';
import 'package:ecoflow/features/auth/domain/verification_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const emailUser = AuthUser(uid: 'u', email: 'a@b.tn', providerIds: ['password']);
  const verified = AuthUser(uid: 'u', email: 'a@b.tn', emailVerified: true, providerIds: ['password']);
  const phoneUser = AuthUser(uid: 'u', phoneNumber: '+21622123456', providerIds: ['phone']);
  const profile = AppUser(uid: 'u', displayName: 'Amine Ben Ali', role: UserRole.citizen);

  SessionState s(AuthUser? u, {bool profileLoaded = true, AppUser? p}) => computeSession(
      authLoaded: true, authUser: u, profileLoaded: profileLoaded, profile: p);

  test('status transitions', () {
    expect(computeSession(authLoaded: false, authUser: null, profileLoaded: false, profile: null).status,
        SessionStatus.loading);
    expect(s(null).status, SessionStatus.signedOut);
    expect(s(emailUser).status, SessionStatus.needsEmailVerification);
    expect(s(verified, profileLoaded: false).status, SessionStatus.loading);
    expect(s(verified).status, SessionStatus.needsProfile);
    expect(s(phoneUser, p: profile).status, SessionStatus.ready);
    expect(s(phoneUser, p: profile).role, UserRole.citizen);
  });

  test('user helpers', () {
    expect(profile.firstName, 'Amine');
    expect(profile.initials, 'AB');
    expect(phoneUser.needsEmailVerification, isFalse);
  });

  test('roles: admin is never self-selectable', () {
    expect(UserRole.selectable, [UserRole.citizen, UserRole.collector, UserRole.recycler]);
    expect(UserRole.collector.requiresVerification, isTrue);
    expect(UserRole.citizen.requiresVerification, isFalse);
  });

  test('verification status', () {
    expect(VerificationStatus.initialFor(true), VerificationStatus.notSubmitted);
    expect(VerificationStatus.initialFor(false), VerificationStatus.notRequired);
    expect(VerificationStatus.rejected.canSubmit, isTrue);
    expect(VerificationStatus.pending.canSubmit, isFalse);
    expect(VerificationStatus.fromName('bogus'), VerificationStatus.notRequired);
  });

  test('firebase error codes are mapped', () {
    expect(mapFirebaseAuthCode('invalid-credential'), AuthFailureCode.wrongCredentials);
    expect(mapFirebaseAuthCode('email-already-in-use'), AuthFailureCode.emailInUse);
    expect(mapFirebaseAuthCode('session-expired'), AuthFailureCode.codeExpired);
    expect(mapFirebaseAuthCode('operation-not-allowed'), AuthFailureCode.providerUnavailable);
    expect(mapFirebaseAuthCode('whatever'), AuthFailureCode.unknown);
  });
}
