import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/sign_up_controller.dart';
import '../../domain/user_role.dart';
import '../../domain/validators.dart';
import '../widgets/auth_messages.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/consent_checkbox.dart';
import '../widgets/error_banner.dart';
import '../widgets/role_picker.dart';

/// Inscription par e-mail avec choix du rôle et consentement (US-001, US-003).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.initialRole});

  final UserRole? initialRole;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late UserRole _role = widget.initialRole?.isSelfSelectable == true
      ? widget.initialRole!
      : UserRole.citizen;
  bool _consent = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await ref
        .read(signUpControllerProvider.notifier)
        .signUpWithEmail(
          displayName: _name.text,
          email: _email.text,
          password: _password.text,
          role: _role,
          consent: _consent,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(signUpControllerProvider);
    return AuthScaffold(
      title: l.signUpTitle,
      subtitle: l.signUpSubtitle,
      emoji: '🌱',
      gradient: roleGradient(_role),
      footer: [
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l.haveAccount),
            EcoLink(label: l.signInButton, onPressed: () => context.push(Routes.signIn)),
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
                label: l.fullNameLabel,
                emoji: '🙂',
                controller: _name,
                autofillHints: const [AutofillHints.name],
                validator: fieldValidator(context, (v) => validateRequired(v, maxLength: 80)),
              ),
              const SizedBox(height: 12),
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
                helper: l.passwordHint,
                newPassword: true,
                validator: fieldValidator(context, validatePassword),
              ),
              const SizedBox(height: 12),
              PasswordField(
                label: l.confirmPasswordLabel,
                controller: _confirm,
                newPassword: true,
                textInputAction: TextInputAction.done,
                validator: fieldValidator(
                  context,
                  (v) => validatePasswordConfirmation(_password.text, v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        RolePicker(value: _role, onChanged: (r) => setState(() => _role = r)),
        const SizedBox(height: 14),
        ConsentCheckbox(value: _consent, onChanged: (v) => setState(() => _consent = v)),
        const SizedBox(height: 8),
        if (state.error != null) ...[
          ErrorBanner(failureText(context, state.error!)),
          const SizedBox(height: 12),
        ],
        EcoButton(
          label: l.signUpButton,
          loading: state.isLoading,
          onPressed: _consent ? _submit : null,
        ),
        const SizedBox(height: 10),
        EcoLink(
          label: l.signUpWithPhone,
          color: EcoColors.primary,
          onPressed: () => context.push(Routes.phone),
        ),
      ],
    );
  }
}
