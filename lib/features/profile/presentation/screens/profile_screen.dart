import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/localization/language_controller.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/domain/validators.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../../auth/presentation/widgets/role_picker.dart';
import '../../application/data_export_controller.dart';
import '../../application/settings_controller.dart';
import '../widgets/menu_tile.dart';
import '../widgets/verification_widgets.dart';

/// Profil : identité, accès au dossier selon le rôle, préférences, données.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(dataExportControllerProvider);
    final l = context.l10n;
    final profile = ref.watch(sessionProvider).profile;
    if (profile == null) return const SizedBox.shrink();
    final language = ref.watch(languageControllerProvider);
    ref.watch(settingsControllerProvider); // garde le controller actif pendant l'écran
    final since = profile.createdAt == null
        ? null
        : DateFormat.yMMMM(language.code).format(profile.createdAt!);
    return LayeredPage(
      header: HeroHeader(
        title: l.profileTitle,
        subtitle: l.profileSubtitle,
        gradient: roleGradient(profile.role),
        emoji: '🙂',
      ),
      children: [
        EcoCard(
          child: Row(
            children: [
              EcoAvatar(text: profile.initials, gradient: roleGradient(profile.role), size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.displayName, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      profile.email ?? profile.phoneNumber ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        EcoChip(label: '${roleEmoji(profile.role)} ${roleLabel(l, profile.role)}'),
                        if (profile.role.requiresVerification)
                          StatusChip(profile.verificationStatus),
                        if (since != null) EcoChip(label: l.memberSince(since), tone: ChipTone.sky),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.editName,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editName(context, ref, profile.displayName),
              ),
            ],
          ),
        ),
        const SizedBox(height: 0),
        SectionTitle(l.sectionAccount),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              if (profile.role == UserRole.citizen)
                MenuTile(
                  emoji: '📍',
                  label: l.addressesMenu,
                  onTap: () => context.go(Routes.addresses),
                ),
              if (profile.role == UserRole.collector)
                MenuTile(
                  emoji: '🚐',
                  label: l.vehicleTitle,
                  onTap: () => context.go(Routes.vehicle),
                ),
              if (profile.role == UserRole.collector)
                MenuTile(
                  emoji: '🪪',
                  label: l.documentsMenu,
                  onTap: () => context.go(Routes.documents),
                ),
              if (profile.role == UserRole.recycler)
                MenuTile(
                  emoji: '🏭',
                  label: l.companyMenu,
                  onTap: () => context.go(Routes.company),
                ),
              MenuTile(
                emoji: '🚪',
                label: l.signOut,
                showDivider: false,
                onTap: () => ref.read(settingsControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
        SectionTitle(l.sectionPreferences),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              MenuTile(
                emoji: '🌐',
                label: l.languageMenu,
                gradient: EcoGradients.sky,
                trailing: EcoChip(
                  label: '${language.flag} ${language.nativeName}',
                  tone: ChipTone.sky,
                ),
                onTap: () => context.push(Routes.language),
              ),
              MenuTile(
                emoji: '🔔',
                label: l.notificationsMenu,
                gradient: EcoGradients.sun,
                showDivider: false,
                onTap: () => context.go(Routes.notifications),
              ),
            ],
          ),
        ),
        SectionTitle(l.sectionDanger),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              MenuTile(
                emoji: '🛡️',
                label: l.privacyMenu,
                gradient: EcoGradients.violet,
                onTap: () => context.push(Routes.privacy),
              ),
              MenuTile(
                emoji: '📦',
                label: l.dataExportMenu,
                gradient: EcoGradients.sky,
                onTap: () async {
                  final ok = await ref.read(dataExportControllerProvider.notifier).export();
                  if (context.mounted && !ok) showEcoToast(context, l.dataExportFailed);
                },
              ),
              MenuTile(
                emoji: '🗑️',
                label: l.deleteAccountMenu,
                gradient: EcoGradients.coral,
                danger: true,
                showDivider: false,
                onTap: () => context.go(Routes.deleteAccount),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final l = context.l10n;
    final controller = TextEditingController(text: current);
    final key = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.editName, style: AppTheme.weighted(22, 800)),
        content: Form(
          key: key,
          child: EcoTextField(
            label: l.fullNameLabel,
            controller: controller,
            validator: fieldValidator(ctx, (v) => validateRequired(v, maxLength: 80)),
          ),
        ),
        actions: [
          EcoLink(label: l.commonCancel, onPressed: () => Navigator.pop(ctx, false)),
          EcoLink(
            label: l.commonSave,
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, true);
            },
          ),
        ],
      ),
    );
    if (saved == true) {
      final ok = await ref
          .read(settingsControllerProvider.notifier)
          .updateDisplayName(controller.text);
      if (ok && context.mounted) showEcoToast(context, l.nameSaved);
    }
    controller.dispose();
  }
}
