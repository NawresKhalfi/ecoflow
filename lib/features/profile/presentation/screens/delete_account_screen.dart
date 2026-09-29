import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/error_banner.dart';
import '../../application/account_deletion_controller.dart';

/// Suppression du compte en 2 étapes (US-010).
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _word = TextEditingController();
  final _password = TextEditingController();
  int _step = 1;

  @override
  void dispose() {
    _word.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ctrl = ref.read(accountDeletionControllerProvider.notifier);
    final state = ref.watch(accountDeletionControllerProvider);
    final usesPassword = ref.watch(authStateProvider).value?.usesPassword ?? false;
    const word = AccountDeletionController.confirmationWord;
    return LayeredPage(
      header: HeroHeader(title: l.deleteTitle, subtitle: l.deleteSubtitle, emoji: '🗑️', gradient: EcoGradients.coral),
      children: [
        EcoCard(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _step == 1
                ? Column(
                    key: const ValueKey(1),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.deleteStep1, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final (e, t) in [('🕶️', l.deleteWhat1), ('🧾', l.deleteWhat2), ('⚠️', l.deleteWhat3)])
                        EcoListTile(leading: EcoAvatar(text: e, size: 40), title: t, showDivider: false),
                      const SizedBox(height: 8),
                      EcoTextField(
                        label: l.deleteTypeWord(word),
                        emoji: '✍️',
                        controller: _word,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      ListenableBuilder(
                        listenable: _word,
                        builder: (context, _) => EcoButton(
                          label: l.commonContinue,
                          onPressed: ctrl.isConfirmationValid(_word.text) ? () => setState(() => _step = 2) : null,
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey(2),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.deleteStep2, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      if (usesPassword)
                        PasswordField(label: l.passwordLabel, controller: _password, textInputAction: TextInputAction.done)
                      else
                        Text(l.deleteReauthOther),
                      const SizedBox(height: 12),
                      if (state.error != null) ...[
                        ErrorBanner(failureText(context, state.error!)),
                        const SizedBox(height: 12),
                      ],
                      EcoButton(
                        label: l.deleteConfirm,
                        leading: '🗑️',
                        loading: state.isLoading,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await ctrl.deleteAccount(password: usesPassword ? _password.text : null);
                          if (ok) messenger.showSnackBar(SnackBar(content: Text(l.deleteDone)));
                        },
                      ),
                      EcoLink(label: l.commonBack, onPressed: () => setState(() => _step = 1)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
