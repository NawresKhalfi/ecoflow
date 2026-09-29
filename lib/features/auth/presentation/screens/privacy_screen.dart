import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../widgets/auth_scaffold.dart';

/// Politique de confidentialité résumée (consentement éclairé).
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = [
      ('⚖️', l.privacyIntro),
      ('🗂️', l.privacyData),
      ('🔐', l.privacyUse),
      ('🙋', l.privacyRights),
    ];
    return AuthScaffold(
      title: l.privacyTitle,
      subtitle: l.privacyIntro,
      emoji: '🛡️',
      gradient: EcoGradients.violet,
      children: [
        for (final (i, (emoji, text)) in items.indexed)
          EcoListTile(
            leading: EcoAvatar(text: emoji),
            title: text,
            showDivider: i < items.length - 1,
          ),
      ],
    );
  }
}
