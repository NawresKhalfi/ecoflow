import 'package:flutter/material.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../domain/user_role.dart';
import 'auth_messages.dart';

Gradient roleGradient(UserRole r) => switch (r) {
      UserRole.citizen => EcoGradients.green,
      UserRole.collector => EcoGradients.coral,
      UserRole.recycler => EcoGradients.sky,
      UserRole.admin => EcoGradients.violet,
    };

/// Sélecteur de rôle (US-003) : seuls les rôles auto-attribuables sont
/// proposés, l'administrateur n'apparaît jamais.
class RolePicker extends StatelessWidget {
  const RolePicker({super.key, required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.chooseRole, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 10),
      for (final role in UserRole.selectable) ...[
        _RoleOption(role: role, selected: role == value, onTap: () => onChanged(role)),
        const SizedBox(height: 10),
      ],
      Text(l.roleAdminNotice, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.role, required this.selected, required this.onTap});

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eco = context.eco;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Pressable(
        lift: 2,
        onTap: onTap,
        semanticLabel: roleLabel(l, role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: selected ? roleGradient(role) : null,
            color: selected ? null : eco.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.transparent : eco.line, width: 2),
          ),
          child: Row(children: [
            Text(roleEmoji(role), style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(roleLabel(l, role),
                    style: AppTheme.weighted(16, 800, color: selected ? Colors.white : eco.ink)),
                Text(roleDescription(l, role),
                    style: AppTheme.weighted(13, 500,
                        color: selected ? Colors.white.withValues(alpha: .9) : eco.muted)),
              ]),
            ),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(Icons.check_circle, color: Colors.white),
            ),
          ]),
        ),
      ),
    );
  }
}
