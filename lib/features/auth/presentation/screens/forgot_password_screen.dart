import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/password_reset_controller.dart';
import '../../domain/validators.dart';
import '../widgets/auth_messages.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/error_banner.dart';

/// Réinitialisation du mot de passe par lien (US-004).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(passwordResetControllerProvider);
    return AuthScaffold(
      title: _sent ? l.forgotSentTitle : l.forgotTitle,
      subtitle: _sent ? l.forgotSentBody : l.forgotSubtitle,
      emoji: _sent ? '✅' : '🗝️',
      gradient: EcoGradients.sun,
      children: _sent
          ? [
              EcoButton(
                label: l.backToSignIn,
                style: EcoButtonStyle.green,
                onPressed: () => context.go(Routes.signIn),
              ),
            ]
          : [
              Form(
                key: _form,
                child: EcoTextField(
                  label: l.emailLabel,
                  emoji: '✉️',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  validator: fieldValidator(context, validateEmail),
                ),
              ),
              const SizedBox(height: 14),
              if (state.error != null) ...[
                ErrorBanner(failureText(context, state.error!)),
                const SizedBox(height: 12),
              ],
              EcoButton(
                label: l.forgotButton,
                loading: state.isLoading,
                onPressed: () async {
                  if (!_form.currentState!.validate()) return;
                  final ok = await ref
                      .read(passwordResetControllerProvider.notifier)
                      .sendReset(_email.text);
                  if (ok && mounted) setState(() => _sent = true);
                },
              ),
            ],
    );
  }
}
