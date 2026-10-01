import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../../../core/localization/l10n.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/eco_widgets.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../auth/domain/user_role.dart';
import '../../../profile/domain/notification_preferences.dart';
import '../../application/tracking_providers.dart';
import '../../domain/app_notification.dart';

String notificationTitle(AppLocalizations l, NotificationType t) => switch (t) {
  NotificationType.assigned => l.ntAssigned,
  NotificationType.onTheWay => l.ntOnTheWay,
  NotificationType.arrived => l.ntArrived,
  NotificationType.handedOver => l.ntHandedOver,
  NotificationType.completed => l.ntCompleted,
  NotificationType.cancelled => l.ntCancelled,
  NotificationType.newMission => l.ntNewMission,
  NotificationType.message => l.ntMessage,
  NotificationType.depositIncoming => l.ntDepositIncoming,
  NotificationType.marketMessage => l.ntMarketMessage,
  NotificationType.marketProposal => l.ntMarketProposal,
  NotificationType.orderUpdate => l.ntOrderUpdate,
  NotificationType.accountReview => l.ntAccountReview,
  NotificationType.disputeUpdate => l.ntDisputeUpdate,
};

/// Écran ouvert par une notification (ouverture directe, US-066).
String routeFor(AppNotification n, UserRole role) => switch (n.type) {
  NotificationType.message => Routes.chat(n.collectionId),
  NotificationType.depositIncoming => Routes.receptions,
  NotificationType.marketMessage || NotificationType.marketProposal => Routes.deal(n.collectionId),
  NotificationType.orderUpdate => Routes.order(n.collectionId),
  NotificationType.accountReview => Routes.home,
  _ =>
    role == UserRole.collector
        ? Routes.missionDetail(n.collectionId)
        : Routes.collectionDetail(n.collectionId),
};

final _seenNotifications = <String>{};
DateTime? _listeningSince;

/// Affiche chaque nouvelle notification reçue : notification système avec
/// son + message dans l'application, selon les préférences (US-009).
/// L'historique (antérieur à l'ouverture de l'espace) n'est jamais re-notifié.
void listenNotifications(BuildContext context, WidgetRef ref) {
  final notifier = ref.read(localNotifierProvider);
  // Préférences du destinataire toujours à jour.
  ref.watch(currentProfileProvider);
  notifier.init((payload) => ref.read(routerProvider).go(payload));
  _listeningSince ??= ref.read(clockProvider)().subtract(const Duration(seconds: 5));
  ref.listen<AsyncValue<List<AppNotification>>>(myNotificationsProvider, (prev, next) {
    final list = next.value;
    if (list == null) return;
    final profile = ref.read(currentProfileProvider).value;
    final prefs = profile?.notificationPreferences ?? NotificationPreferences.defaults;
    final role = profile?.role ?? UserRole.citizen;
    final l = context.l10n;
    for (final n in list) {
      final old = n.createdAt != null && n.createdAt!.isBefore(_listeningSince!);
      if (old || n.read || !_seenNotifications.add(n.id) || !allowedByPreferences(n.type, prefs)) {
        continue;
      }
      final title = notificationTitle(l, n.type);
      final body = n.type == NotificationType.message && n.preview.isNotEmpty
          ? n.preview
          : n.address;
      notifier.show(
        n.id.hashCode,
        title,
        body,
        payload: routeFor(n, role),
        urgent: n.type == NotificationType.newMission,
      );
      showEcoToast(context, '🔔 $title');
    }
  });
}

/// Pour les tests : oublie l'état d'écoute.
@visibleForTesting
void resetNotificationListener() {
  _seenNotifications.clear();
  _listeningSince = null;
}
