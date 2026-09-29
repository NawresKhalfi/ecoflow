import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/auth_providers.dart';
import '../../application/email_verification_controller.dart';
import '../widgets/auth_messages.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/error_banner.dart';

/// Le compte e-mail n'est activé qu'après vérification de l'adresse (US-001).
class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(emailVerificationControllerProvider);
    final ctrl = ref.read(emailVerificationControllerProvider.notifier);
    final email = ref.watch(authStateProvider).value?.email ?? '';
    return AuthScaffold(
      title: l.verifyEmailTitle,
      subtitle: l.verifyEmailBody(email),
      emoji: '📬',
      gradient: EcoGradients.sky,
      showBack: false,
      children: [
        if (state.error != null) ...[
          ErrorBanner(failureText(context, state.error!)),
          const SizedBox(height: 12),
        ],
        EcoButton(
          label: l.verifyEmailCheck,
          style: EcoButtonStyle.green,
          loading: state.isLoading,
          onPressed: () async {
            final ok = await ctrl.check();
            if (ok && !ctrl.lastCheckVerified && context.mounted) {
              showEcoToast(context, l.verifyEmailNotYet);
            }
          },
        ),
        const SizedBox(height: 10),
        EcoButton(
          label: l.verifyEmailResend,
          style: EcoButtonStyle.ghost,
          onPressed: () async {
            if (await ctrl.resend() && context.mounted) showEcoToast(context, l.verifyEmailSent);
          },
        ),
        const SizedBox(height: 6),
        EcoLink(label: l.signOut, onPressed: ctrl.signOut),
      ],
    );
  }
}
