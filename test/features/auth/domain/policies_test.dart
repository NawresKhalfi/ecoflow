import 'package:ecoflow/features/auth/domain/login_lockout_policy.dart';
import 'package:ecoflow/features/auth/domain/otp_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026, 9, 29, 10);

  group('LoginLockoutPolicy', () {
    const policy = LoginLockoutPolicy();

    test('locks after 5 consecutive failures for 15 minutes', () {
      var a = LoginAttempts.none;
      for (var i = 0; i < 4; i++) {
        a = policy.registerFailure(a, t0);
        expect(policy.isLocked(a, t0), isFalse);
      }
      expect(policy.remaining(a), 1);
      a = policy.registerFailure(a, t0);
      expect(policy.isLocked(a, t0), isTrue);
      expect(policy.isLocked(a, t0.add(const Duration(minutes: 14))), isTrue);
      expect(policy.isLocked(a, t0.add(const Duration(minutes: 15))), isFalse);
    });

    test('an expired lock restarts the counter', () {
      var a = LoginAttempts(failures: 5, lockedUntil: t0);
      a = policy.registerFailure(a, t0.add(const Duration(minutes: 1)));
      expect(a.failures, 1);
      expect(a.lockedUntil, isNull);
    });
  });

  group('OtpPolicy', () {
    const policy = OtpPolicy();
    final s = OtpSession(verificationId: 'v', phoneNumber: '+21622123456', sentAt: t0);

    test('code is valid for 5 minutes', () {
      expect(policy.isExpired(s, t0.add(const Duration(minutes: 4, seconds: 59))), isFalse);
      expect(policy.isExpired(s, t0.add(const Duration(minutes: 5))), isTrue);
      expect(policy.remaining(s, t0.add(const Duration(minutes: 6))), Duration.zero);
    });

    test('resend is possible after 30 s', () {
      expect(policy.canResend(s, t0.add(const Duration(seconds: 10))), isFalse);
      expect(policy.canResend(s, t0.add(const Duration(seconds: 30))), isTrue);
    });
  });
}
