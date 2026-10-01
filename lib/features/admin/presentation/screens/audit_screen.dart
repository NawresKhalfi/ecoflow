import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_text_field.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../application/admin_providers.dart';
import '../../domain/admin.dart';

String auditLabel(AppLocalizations l, String action) => switch (action) {
  AuditAction.block => l.auditBlock,
  AuditAction.unblock => l.auditUnblock,
  AuditAction.approve => l.auditApprove,
  AuditAction.reject => l.auditReject,
  AuditAction.permissions => l.auditPermissions,
  AuditAction.promote => l.auditPromote,
  AuditAction.demote => l.auditDemote,
  AuditAction.dispute => l.auditDispute,
  AuditAction.broadcast => l.auditBroadcast,
  AuditAction.zones => l.auditZones,
  _ => action,
};

/// Journal d'audit des actions sensibles (US-114), en lecture seule.
class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    final q = _q.text.trim().toLowerCase();
    final entries = (ref.watch(auditProvider).value ?? const <AuditEntry>[])
        .where(
          (e) =>
              q.isEmpty ||
              [
                e.actorName,
                e.targetId,
                e.details,
                auditLabel(l, e.action),
              ].any((v) => v.toLowerCase().contains(q)),
        )
        .toList();
    return LayeredPage(
      header: HeroHeader(
        title: l.auditTitle,
        subtitle: l.auditSubtitle,
        emoji: '📜',
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
          label: l.auditSearch,
          controller: _q,
          emoji: '🔎',
          onChanged: (_) => setState(() {}),
        ),
        if (entries.isEmpty) EcoCard(child: Text(l.auditEmpty)),
        if (entries.isNotEmpty)
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, e) in entries.indexed)
                  EcoListTile(
                    leading: const EcoAvatar(text: '🕒'),
                    title:
                        '${auditLabel(l, e.action)} · ${e.targetType} ${e.targetId.length > 8 ? e.targetId.substring(0, 8) : e.targetId}',
                    subtitle: [
                      e.actorName,
                      if (e.at != null) DateFormat.yMMMd(lang).add_Hm().format(e.at!),
                      if (e.details.isNotEmpty) e.details,
                    ].join(' · '),
                    showDivider: i < entries.length - 1,
                  ),
              ],
            ),
          ),
        EcoCard(child: Text('🔒 ${l.auditImmutable}')),
      ],
    );
  }
}
