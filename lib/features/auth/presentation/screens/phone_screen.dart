import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/auth_providers.dart';
import '../../application/phone_auth_controller.dart';
import '../../domain/validators.dart';
import '../widgets/auth_messages.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/error_banner.dart';

/// Inscription / connexion par SMS (US-001). Après vérification, la
/// navigation redirige vers la finalisation du profil si nécessaire.
class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phoneForm = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Rafraîchit le compte à rebours du code.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(phoneAuthControllerProvider).session != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String _mmss(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(phoneAuthControllerProvider);
    final ctrl = ref.read(phoneAuthControllerProvider.notifier);
    final codeStep =
        state.session != null &&
        (state.phase == PhoneAuthPhase.enterCode || state.phase == PhoneAuthPhase.verifying);
    return AuthScaffold(
      title: codeStep ? l.otpTitle : l.phoneTitle,
      subtitle: codeStep ? l.otpSubtitle(state.session!.phoneNumber) : l.phoneSubtitle,
      emoji: codeStep ? '💬' : '📱',
      gradient: EcoGradients.violet,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: codeStep
              ? _codeStep(context, state, ctrl)
              : Form(
                  key: _phoneForm,
                  child: EcoTextField(
                    key: const ValueKey('phone'),
                    label: l.phoneLabel,
                    hint: l.phoneHint,
                    emoji: '🇹🇳',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.done,
                    validator: fieldValidator(context, validatePhone),
                  ),
                ),
        ),
        const SizedBox(height: 14),
        if (state.error != null) ...[
          ErrorBanner(failureText(context, state.error!)),
          const SizedBox(height: 12),
        ],
        if (!codeStep)
          EcoButton(
            label: l.sendCode,
            style: EcoButtonStyle.green,
            loading: state.phase == PhoneAuthPhase.sending,
            onPressed: () {
              if (_phoneForm.currentState!.validate()) ctrl.sendCode(_phone.text);
            },
          ),
      ],
    );
  }

  Widget _codeStep(BuildContext context, PhoneAuthState state, PhoneAuthController ctrl) {
    final l = context.l10n;
    final policy = ref.read(otpPolicyProvider);
    final now = ref.read(clockProvider)();
    final session = state.session!;
    final expired = policy.isExpired(session, now);
    final canResend = policy.canResend(session, now);
    final resendWait = session.sentAt.add(policy.resendCooldown).difference(now).inSeconds + 1;
    return Column(
      key: const ValueKey('code'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EcoTextField(
          label: l.otpLabel,
          emoji: '🔢',
          controller: _code,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => ctrl.confirm(v),
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: EcoChip(
            tone: expired ? ChipTone.coral : ChipTone.sun,
            label: expired ? l.otpExpired : l.otpExpiresIn(_mmss(policy.remaining(session, now))),
          ),
        ),
        const SizedBox(height: 14),
        EcoButton(
          label: l.verifyCode,
          style: EcoButtonStyle.green,
          loading: state.phase == PhoneAuthPhase.verifying,
          onPressed: expired ? null : () => ctrl.confirm(_code.text),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            EcoLink(
              label: canResend ? l.resendCode : l.resendIn(resendWait),
              onPressed: canResend
                  ? () {
                      _code.clear();
                      HapticFeedback.selectionClick();
                      ctrl.resend();
                    }
                  : null,
            ),
            EcoLink(label: l.changeNumber, onPressed: ctrl.changeNumber),
          ],
        ),
      ],
    );
  }
}
