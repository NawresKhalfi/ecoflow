import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/auth_providers.dart';
import '../../application/sign_up_controller.dart';
import '../../domain/user_role.dart';
import '../../domain/validators.dart';
import '../widgets/auth_messages.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/consent_checkbox.dart';
import '../widgets/error_banner.dart';
import '../widgets/role_picker.dart';

/// Après une connexion téléphone / Google : nom, rôle et consentement.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: ref.read(authRepositoryProvider).currentUser?.displayName);
  UserRole _role = UserRole.citizen;
  bool _consent = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final state = ref.watch(signUpControllerProvider);
    return AuthScaffold(
      title: l.completeTitle,
      subtitle: l.completeSubtitle,
      emoji: '✨',
      gradient: roleGradient(_role),
      showBack: false,
      footer: [
        Center(
          child: EcoLink(
            label: l.signOut,
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ),
      ],
      children: [
        Form(
          key: _form,
          child: EcoTextField(
            label: l.fullNameLabel,
            emoji: '🙂',
            controller: _name,
            autofillHints: const [AutofillHints.name],
            validator: fieldValidator(context, (v) => validateRequired(v, maxLength: 80)),
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
          label: l.completeButton,
          loading: state.isLoading,
          onPressed: !_consent
              ? null
              : () {
                  if (!_form.currentState!.validate()) return;
                  ref.read(signUpControllerProvider.notifier).completeProfile(
                      displayName: _name.text, role: _role, consent: _consent);
                },
        ),
      ],
    );
  }
}
