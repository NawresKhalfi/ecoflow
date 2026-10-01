import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presentation/widgets/auth_messages.dart';
import '../../application/admin_providers.dart';
import '../../domain/admin.dart';

/// Comptes : recherche, blocage, réactivation (US-106) ; avec
/// [adminsOnly], gestion des administrateurs et de leurs permissions (US-113).
class UsersAdminScreen extends ConsumerStatefulWidget {
  const UsersAdminScreen({super.key, this.adminsOnly = false});
  final bool adminsOnly;

  @override
  ConsumerState<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends ConsumerState<UsersAdminScreen> {
  final _q = TextEditingController();
  UserRole? _role;
  bool _blockedOnly = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(sessionProvider).profile;
    // Écouté : le contrôleur (auto-libéré) doit survivre à la feuille d'actions.
    ref.watch(adminControllerProvider);
    final all = ref.watch(adminUsersProvider).value ?? const <AdminUserView>[];
    final shown = all
        .where(
          (u) =>
              u.matches(_q.text) &&
              (widget.adminsOnly ? true : _role == null || u.role == _role) &&
              (!_blockedOnly || u.blocked),
        )
        .toList();
    return LayeredPage(
      header: HeroHeader(
        title: widget.adminsOnly ? l.adminsTitle : l.usersTitle,
        subtitle: widget.adminsOnly ? l.adminsSubtitle : l.usersSubtitle,
        emoji: widget.adminsOnly ? '🔐' : '👥',
        gradient: EcoGradients.violet,
        leading: IconButton.filledTonal(
          tooltip: l.commonBack,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .22),
            foregroundColor: Colors.white,
          ),
          onPressed: () => context.go(Routes.supervision),
          icon: const BackButtonIcon(),
        ),
      ),
      children: [
        EcoTextField(
          label: l.usersSearch,
          controller: _q,
          emoji: '🔎',
          onChanged: (_) => setState(() {}),
        ),
        if (!widget.adminsOnly)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              EcoChip(
                label: l.rewardsAll,
                selected: _role == null,
                onTap: () => setState(() => _role = null),
              ),
              for (final r in UserRole.values)
                EcoChip(
                  label: roleLabel(l, r),
                  selected: _role == r,
                  onTap: () => setState(() => _role = r),
                ),
              EcoChip(
                label: '⛔ ${l.usersBlocked}',
                tone: ChipTone.coral,
                selected: _blockedOnly,
                onTap: () => setState(() => _blockedOnly = !_blockedOnly),
              ),
            ],
          ),
        Text(l.usersCount(shown.length), style: Theme.of(context).textTheme.bodySmall),
        EcoCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              for (final (i, u) in shown.take(200).indexed)
                EcoListTile(
                  leading: EcoAvatar(text: u.blocked ? '⛔' : roleEmoji(u.role)),
                  title: u.displayName.isEmpty ? u.uid : u.displayName,
                  subtitle: [
                    roleLabel(l, u.role),
                    ?u.email,
                    if (u.role == UserRole.admin)
                      u.isSuperAdmin ? l.adminSuper : (u.adminPermissions!.join(', ')),
                    if (u.blocked) '⛔ ${u.blockedReason ?? ''}',
                  ].join(' · '),
                  onTap: u.uid == me?.uid ? null : () => _actions(context, u),
                  showDivider: i < shown.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _actions(BuildContext context, AdminUserView u) async {
    final l = context.l10n;
    final me = ref.read(sessionProvider).profile;
    final reason = TextEditingController(text: u.blockedReason);
    final perms = <String>{...?u.adminPermissions};
    var superAdmin = u.isSuperAdmin;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          final ctrl = ref.read(adminControllerProvider.notifier);
          Future<void> done(Future<bool> f) async {
            if (await f && c.mounted) Navigator.pop(c);
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + MediaQuery.viewInsetsOf(c).bottom),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(u.displayName, style: Theme.of(c).textTheme.titleLarge),
                  Text('${roleLabel(l, u.role)} · ${u.email ?? u.phone ?? u.uid}'),
                  const SizedBox(height: 12),
                  if (me?.can(AdminPermission.users) ?? false) ...[
                    EcoTextField(label: l.usersBlockReason, controller: reason, maxLength: 200),
                    EcoButton(
                      label: u.blocked ? l.usersUnblock : l.usersBlock,
                      leading: u.blocked ? '✅' : '⛔',
                      style: u.blocked ? EcoButtonStyle.green : EcoButtonStyle.coral,
                      onPressed: () =>
                          done(ctrl.setBlocked(u, blocked: !u.blocked, reason: reason.text)),
                    ),
                  ],
                  if (me?.isSuperAdmin ?? false) ...[
                    const Divider(height: 28),
                    Text('🔐 ${l.adminsTitle}', style: Theme.of(c).textTheme.titleMedium),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: superAdmin,
                      title: Text(l.adminSuper),
                      onChanged: (v) => set(() => superAdmin = v),
                    ),
                    if (!superAdmin)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final p in AdminPermission.all)
                            EcoChip(
                              label: permissionLabel(l, p),
                              selected: perms.contains(p),
                              onTap: () =>
                                  set(() => perms.contains(p) ? perms.remove(p) : perms.add(p)),
                            ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    EcoButton(
                      label: u.role == UserRole.admin ? l.adminsSave : l.adminsPromote,
                      style: EcoButtonStyle.green,
                      onPressed: () => done(
                        ctrl.setAdmin(u, admin: true, permissions: superAdmin ? null : perms),
                      ),
                    ),
                    if (u.role == UserRole.admin)
                      EcoLink(
                        label: l.adminsDemote,
                        color: const Color(0xFFC4482A),
                        onPressed: () => done(ctrl.setAdmin(u, admin: false)),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
    disposeAfterSheet([reason]);
  }
}

String permissionLabel(AppLocalizations l, String p) => switch (p) {
  AdminPermission.users => l.permUsers,
  AdminPermission.verifications => l.permVerifications,
  AdminPermission.disputes => l.permDisputes,
  AdminPermission.broadcast => l.permBroadcast,
  AdminPermission.zones => l.permZones,
  AdminPermission.audit => l.permAudit,
  AdminPermission.market => l.permMarket,
  _ => p,
};
