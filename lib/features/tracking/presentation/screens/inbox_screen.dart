import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
import '../../application/tracking_providers.dart';
import '../widgets/notification_listener.dart';

/// Historique des notifications reçues.
class InboxScreen extends ConsumerWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final list = ref.watch(myNotificationsProvider).value ?? const [];
    final role = ref.watch(currentProfileProvider).value?.role ?? UserRole.citizen;
    final unread = ref.watch(unreadCountProvider);
    final fmt = DateFormat.MMMd(Localizations.localeOf(context).languageCode).add_Hm();
    return LayeredPage(
      header: HeroHeader(
        title: l.inboxTitle,
        subtitle: l.inboxSubtitle,
        emoji: '🔔',
        gradient: EcoGradients.sun,
      ),
      children: [
        EcoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: EcoChip(
                      label: l.inboxUnread(unread),
                      tone: unread == 0 ? ChipTone.green : ChipTone.coral,
                    ),
                  ),
                  if (unread > 0)
                    EcoLink(
                      label: l.inboxMarkAll,
                      onPressed: () => ref.read(notificationRepositoryProvider).markAllRead(list),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(l.inboxPushOff, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (list.isEmpty)
          EcoCard(child: Text(l.inboxEmpty))
        else
          EcoCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Column(
              children: [
                for (final (i, n) in list.indexed)
                  EcoListTile(
                    leading: EcoAvatar(
                      text: n.read ? '🔕' : '🔔',
                      gradient: n.read ? null : EcoGradients.coral,
                    ),
                    title: notificationTitle(l, n.type),
                    subtitle: [
                      n.preview.isNotEmpty ? n.preview : n.address,
                      if (n.createdAt != null) fmt.format(n.createdAt!),
                    ].join('\n'),
                    showDivider: i < list.length - 1,
                    onTap: () {
                      if (!n.read) ref.read(notificationRepositoryProvider).markRead(n.id);
                      context.go(routeFor(n, role));
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
