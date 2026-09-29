import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/localization/language_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/presentation/widgets/auth_scaffold.dart';
import '../../application/settings_controller.dart';

/// Choix de la langue, appliqué à chaud (RTL pour l'arabe) — US-008.
class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final current = ref.watch(languageControllerProvider);
    return AuthScaffold(
      title: l.languageTitle,
      subtitle: l.languageSubtitle,
      emoji: '🌐',
      gradient: EcoGradients.sky,
      children: [
        for (final (i, lang) in AppLanguage.values.indexed)
          Semantics(
            selected: lang == current,
            inMutuallyExclusiveGroup: true,
            child: EcoListTile(
              leading: EcoAvatar(text: lang.flag),
              title: lang.nativeName,
              subtitle: lang.code.toUpperCase(),
              showDivider: i < AppLanguage.values.length - 1,
              trailing: AnimatedScale(
                scale: lang == current ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.check_circle, color: EcoColors.primary),
              ),
              onTap: () => ref.read(settingsControllerProvider.notifier).selectLanguage(lang),
            ),
          ),
      ],
    );
  }
}
