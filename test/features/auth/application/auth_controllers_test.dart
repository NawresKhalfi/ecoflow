import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/application/password_reset_controller.dart';
import 'package:ecoflow/features/auth/application/phone_auth_controller.dart';
import 'package:ecoflow/features/auth/application/sign_in_controller.dart';
import 'package:ecoflow/features/auth/application/sign_up_controller.dart';
import 'package:ecoflow/features/auth/domain/auth_failure.dart';
import 'package:ecoflow/features/auth/domain/session_state.dart';
import 'package:ecoflow/features/auth/domain/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeFirebaseFirestore db;
  late DateTime now;
  late ProviderContainer c;

  setUp(() async {
    auth = FakeAuthRepository();
    db = FakeFirebaseFirestore();
    now = DateTime(2026, 9, 29, 10);
    c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
  });

  AuthFailureCode? code(AsyncValue<void> s) => (s.error as AuthFailure?)?.code;

  group('SignInController (US-002)', () {
    test('signs in with valid credentials', () async {
      auth.passwords['a@b.tn'] = 'recycle26';
      c.listen(signInControllerProvider, (_, _) {});
      expect(
        await c.read(signInControllerProvider.notifier).signInWithEmail('a@b.tn', 'recycle26'),
        isTrue,
      );
      expect(auth.currentUser?.email, 'a@b.tn');
    });

    test('locks after 5 failures then unlocks after 15 minutes', () async {
      auth.passwords['a@b.tn'] = 'recycle26';
      c.listen(signInControllerProvider, (_, _) {});
      final ctrl = c.read(signInControllerProvider.notifier);
      for (var i = 0; i < 4; i++) {
        await ctrl.signInWithEmail('a@b.tn', 'bad');
        expect(code(c.read(signInControllerProvider)), AuthFailureCode.wrongCredentials);
      }
      expect(ctrl.remainingAttempts('a@b.tn'), 1);
      await ctrl.signInWithEmail('a@b.tn', 'bad');
      expect(code(c.read(signInControllerProvider)), AuthFailureCode.lockedOut);

      // Même le bon mot de passe est refusé pendant le verrouillage.
      await ctrl.signInWithEmail('a@b.tn', 'recycle26');
      expect(code(c.read(signInControllerProvider)), AuthFailureCode.lockedOut);
      expect(auth.currentUser, isNull);

      now = now.add(const Duration(minutes: 15));
      expect(await ctrl.signInWithEmail('a@b.tn', 'recycle26'), isTrue);
      expect(ctrl.remainingAttempts('a@b.tn'), 5);
    });
  });

  group('SignUpController (US-001/003)', () {
    test('creates the account and the Firestore profile with consent', () async {
      c.listen(signUpControllerProvider, (_, _) {});
      final ok = await c
          .read(signUpControllerProvider.notifier)
          .signUpWithEmail(
            displayName: 'Sana M',
            email: 's@b.tn',
            password: 'recycle26',
            role: UserRole.recycler,
            consent: true,
          );
      expect(ok, isTrue);
      expect(auth.verificationEmails, 1);
      final doc = (await db.doc('users/uid-s@b.tn').get()).data()!;
      expect(doc['role'], 'recycler');
      expect(doc['verificationStatus'], 'notSubmitted');
      expect(doc['consent']['version'], isNotNull);
    });

    test('writes nothing without consent', () async {
      c.listen(signUpControllerProvider, (_, _) {});
      await c
          .read(signUpControllerProvider.notifier)
          .signUpWithEmail(
            displayName: 'X',
            email: 'x@b.tn',
            password: 'recycle26',
            role: UserRole.citizen,
            consent: false,
          );
      expect(c.read(signUpControllerProvider).error, isA<ConsentRequired>());
      expect(auth.currentUser, isNull);
      expect((await db.collection('users').get()).docs, isEmpty);
    });

    test('never allows the admin role', () async {
      c.listen(signUpControllerProvider, (_, _) {});
      final ok = await c
          .read(signUpControllerProvider.notifier)
          .signUpWithEmail(
            displayName: 'X',
            email: 'x@b.tn',
            password: 'recycle26',
            role: UserRole.admin,
            consent: true,
          );
      expect(ok, isFalse);
      expect((await db.collection('users').get()).docs, isEmpty);
    });

    test('session goes verification → ready as the user progresses', () async {
      c.listen(sessionProvider, (_, _) {});
      c.listen(signUpControllerProvider, (_, _) {});
      await c
          .read(signUpControllerProvider.notifier)
          .signUpWithEmail(
            displayName: 'Amine',
            email: 'a@b.tn',
            password: 'recycle26',
            role: UserRole.citizen,
            consent: true,
          );
      await pumpEventQueue();
      expect(c.read(sessionProvider).status, SessionStatus.needsEmailVerification);

      auth.verifiedEmails.add('a@b.tn');
      await auth.signInWithEmail('a@b.tn', 'recycle26');
      await pumpEventQueue();
      expect(c.read(sessionProvider).status, SessionStatus.ready);
      expect(c.read(sessionProvider).role, UserRole.citizen);
    });

    test('phone users complete their profile afterwards', () async {
      c.listen(sessionProvider, (_, _) {});
      c.listen(signUpControllerProvider, (_, _) {});
      await pumpEventQueue();
      await auth.sendPhoneCode('+21622123456');
      await auth.confirmPhoneCode('vid-1', '123456');
      await pumpEventQueue();
      expect(c.read(sessionProvider).status, SessionStatus.needsProfile);
      await c
          .read(signUpControllerProvider.notifier)
          .completeProfile(displayName: 'Karim', role: UserRole.collector, consent: true);
      await pumpEventQueue();
      final s = c.read(sessionProvider);
      expect(s.status, SessionStatus.ready);
      expect(s.profile!.phoneNumber, '+21622123456');
    });
  });

  group('PhoneAuthController (US-001)', () {
    test('sends a code to the normalized number and verifies it', () async {
      c.listen(phoneAuthControllerProvider, (_, _) {});
      final ctrl = c.read(phoneAuthControllerProvider.notifier);
      await ctrl.sendCode('22 123 456');
      expect(auth.sentCodes.single, '+21622123456');
      expect(c.read(phoneAuthControllerProvider).phase, PhoneAuthPhase.enterCode);

      await ctrl.confirm('000000');
      expect(
        (c.read(phoneAuthControllerProvider).error as AuthFailure).code,
        AuthFailureCode.invalidCode,
      );

      await ctrl.confirm('123456');
      expect(c.read(phoneAuthControllerProvider).phase, PhoneAuthPhase.verified);
    });

    test('rejects an invalid number without calling Firebase', () async {
      c.listen(phoneAuthControllerProvider, (_, _) {});
      await c.read(phoneAuthControllerProvider.notifier).sendCode('123');
      expect(auth.sentCodes, isEmpty);
      expect(
        (c.read(phoneAuthControllerProvider).error as AuthFailure).code,
        AuthFailureCode.invalidPhone,
      );
    });

    test('code expires after 5 minutes; resend waits 30 s', () async {
      c.listen(phoneAuthControllerProvider, (_, _) {});
      final ctrl = c.read(phoneAuthControllerProvider.notifier);
      await ctrl.sendCode('+21622123456');
      await ctrl.resend();
      expect(auth.sentCodes, hasLength(1), reason: 'cooldown not elapsed');

      now = now.add(const Duration(minutes: 5));
      await ctrl.confirm('123456');
      expect(
        (c.read(phoneAuthControllerProvider).error as AuthFailure).code,
        AuthFailureCode.codeExpired,
      );
      expect(auth.currentUser, isNull);

      await ctrl.resend();
      expect(auth.sentCodes, hasLength(2));
      await ctrl.confirm('123456');
      expect(c.read(phoneAuthControllerProvider).phase, PhoneAuthPhase.verified);
    });
  });

  test('PasswordResetController sends the reset link (US-004)', () async {
    c.listen(passwordResetControllerProvider, (_, _) {});
    expect(await c.read(passwordResetControllerProvider.notifier).sendReset('a@b.tn'), isTrue);
    expect(auth.sentResets, ['a@b.tn']);
  });
}
