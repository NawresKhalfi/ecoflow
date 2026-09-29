import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../data/auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/otp_policy.dart';
import '../domain/validators.dart';
import 'auth_providers.dart';

enum PhoneAuthPhase { enterPhone, sending, enterCode, verifying, verified }

class PhoneAuthState {
  const PhoneAuthState({this.phase = PhoneAuthPhase.enterPhone, this.session, this.error});

  final PhoneAuthPhase phase;
  final OtpSession? session;
  final Object? error;

  PhoneAuthState copyWith({PhoneAuthPhase? phase, OtpSession? session, Object? error}) =>
      PhoneAuthState(phase: phase ?? this.phase, session: session ?? this.session, error: error);
}

/// Inscription / connexion par numéro de téléphone avec code SMS (US-001).
/// Le code est considéré expiré après 5 minutes (cf. [OtpPolicy]).
class PhoneAuthController extends Notifier<PhoneAuthState> {
  @override
  PhoneAuthState build() => const PhoneAuthState();

  DateTime _now() => ref.read(clockProvider)();

  Future<void> sendCode(String rawPhone) async {
    final phone = normalizePhone(rawPhone);
    if (phone == null) {
      state = state.copyWith(error: const AuthFailure(AuthFailureCode.invalidPhone));
      return;
    }
    state = state.copyWith(phase: PhoneAuthPhase.sending);
    try {
      final result = await ref.read(authRepositoryProvider).sendPhoneCode(phone);
      if (!ref.mounted) return;
      state = switch (result) {
        PhoneCodeSent(:final verificationId) => PhoneAuthState(
          phase: PhoneAuthPhase.enterCode,
          session: OtpSession(verificationId: verificationId, phoneNumber: phone, sentAt: _now()),
        ),
        PhoneAutoVerified() => const PhoneAuthState(phase: PhoneAuthPhase.verified),
      };
    } catch (e) {
      if (!ref.mounted) return;
      state = PhoneAuthState(
        phase: state.session == null ? PhoneAuthPhase.enterPhone : PhoneAuthPhase.enterCode,
        session: state.session,
        error: e,
      );
    }
  }

  Future<void> resend() async {
    final s = state.session;
    if (s == null || !ref.read(otpPolicyProvider).canResend(s, _now())) return;
    await sendCode(s.phoneNumber);
  }

  Future<void> confirm(String code) async {
    final s = state.session;
    if (s == null) return;
    if (ref.read(otpPolicyProvider).isExpired(s, _now())) {
      state = state.copyWith(error: const AuthFailure(AuthFailureCode.codeExpired));
      return;
    }
    if (validateOtp(code) != null) {
      state = state.copyWith(error: const AuthFailure(AuthFailureCode.invalidCode));
      return;
    }
    state = state.copyWith(phase: PhoneAuthPhase.verifying);
    try {
      await ref.read(authRepositoryProvider).confirmPhoneCode(s.verificationId, code.trim());
      if (ref.mounted) state = state.copyWith(phase: PhoneAuthPhase.verified);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(phase: PhoneAuthPhase.enterCode, error: e);
    }
  }

  /// Retour à la saisie du numéro (numéro erroné).
  void changeNumber() => state = const PhoneAuthState();
}

final phoneAuthControllerProvider =
    NotifierProvider.autoDispose<PhoneAuthController, PhoneAuthState>(PhoneAuthController.new);
