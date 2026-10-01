import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

/// Compte bloqué par l'administration (US-106) : seule la déconnexion reste
/// possible.
class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final reason = ref.watch(sessionProvider).profile?.blockedReason;
    return AuthScaffold(
      title: l.blockedTitle,
      subtitle: l.blockedBody,
      emoji: '⛔',
      gradient: EcoGradients.coral,
      showBack: false,
      children: [
        if (reason != null && reason.isNotEmpty) EcoCard(child: Text('${l.blockedReason} : $reason')),
        EcoButton(
          label: l.signOut,
          style: EcoButtonStyle.ghost,
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
        ),
      ],
    );
  }
}
