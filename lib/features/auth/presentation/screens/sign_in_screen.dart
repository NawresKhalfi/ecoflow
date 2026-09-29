import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/sign_in_controller.dart';
import '../../domain/auth_failure.dart';
import '../../domain/validators.dart';
import '../widgets/auth_messages.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/error_banner.dart';

/// Connexion e-mail / mot de passe ou Google (US-002).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref.read(signInControllerProvider.notifier).signInWithEmail(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(signInControllerProvider);
    final error = state.error;
    final remaining = error is AuthFailure && error.code == AuthFailureCode.wrongCredentials
        ? ref.read(signInControllerProvider.notifier).remainingAttempts(_email.text)
        : null;
    return AuthScaffold(
      title: l.signInTitle,
      subtitle: l.signInSubtitle,
      emoji: '🔑',
      footer: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l.noAccount),
            EcoLink(label: l.createAccount, onPressed: () => context.push(Routes.signUp)),
          ],
        ),
      ],
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EcoTextField(
                label: l.emailLabel,
                emoji: '✉️',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                validator: fieldValidator(context, validateEmail),
              ),
              const SizedBox(height: 12),
              PasswordField(
                label: l.passwordLabel,
                controller: _password,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: fieldValidator(context, (v) => validateRequired(v)),
              ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: EcoLink(
            label: l.forgotPassword,
            onPressed: () => context.push(Routes.forgotPassword),
          ),
        ),
        if (error != null) ...[
          ErrorBanner(
            [
              failureText(context, error),
              if (remaining != null && remaining > 0) l.attemptsLeft(remaining),
            ].join('\n'),
          ),
          const SizedBox(height: 12),
        ],
        EcoButton(
          label: l.signInButton,
          style: EcoButtonStyle.green,
          loading: state.isLoading,
          onPressed: _submit,
        ),
        const _OrDivider(),
        EcoButton(
          label: l.continueWithGoogle,
          leading: 'G',
          style: EcoButtonStyle.ghost,
          onPressed: state.isLoading
              ? null
              : () => ref.read(signInControllerProvider.notifier).signInWithGoogle(),
        ),
        const SizedBox(height: 10),
        EcoButton(
          label: l.continueWithPhone,
          leading: '📱',
          style: EcoButtonStyle.ghost,
          onPressed: () => context.push(Routes.phone),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(context.l10n.commonOr, style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider()),
      ],
    ),
  );
}
