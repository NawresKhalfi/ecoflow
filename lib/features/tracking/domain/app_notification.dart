import '../../profile/domain/notification_preferences.dart';

/// Événements notifiés (US-065, US-066). Le texte est construit à l'affichage
/// dans la langue du destinataire.
enum NotificationType {
  assigned,
  onTheWay,
  arrived,
  handedOver,
  completed,
  cancelled,
  newMission,
  message,

  /// Lot déposé par un collecteur, en route vers le recycleur (US-086) ;
  /// `collectionId` porte alors l'identifiant du dépôt.
  depositIncoming,

  /// Marketplace (US-098 à US-100) : `collectionId` porte l'identifiant du
  /// fil de négociation ou de la commande.
  marketMessage,
  marketProposal,
  orderUpdate,

  /// Administration (US-107, US-112) : dossier examiné, litige traité.
  accountReview,
  disputeUpdate;

  static NotificationType? fromName(String? n) => values.where((v) => v.name == n).firstOrNull;

  /// Catégorie des préférences (US-009) qui autorise ce type.
  NotificationCategory get category => NotificationCategory.collectionStatus;

  /// Événements critiques : SMS de secours si pas de connexion (US-068).
  bool get critical => this == arrived || this == cancelled;
}

/// Notification stockée : `notifications/{id}` (boîte d'envoi lue par
/// l'app du destinataire et, avec le plan Blaze, par la Cloud Function FCM).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.toUid,
    required this.type,
    required this.collectionId,
    this.fromUid,
    this.address = '',
    this.preview = '',
    this.read = false,
    this.createdAt,
  });

  final String id;
  final String toUid;
  final String? fromUid;
  final NotificationType type;
  final String collectionId;
  final String address;

  /// Début du message (type `message`).
  final String preview;
  final bool read;
  final DateTime? createdAt;
}

/// Statut de collecte → notification pour le citoyen (US-065).
NotificationType? statusNotification(String status) => switch (status) {
  'accepted' => NotificationType.assigned,
  'onTheWay' => NotificationType.onTheWay,
  'arrived' => NotificationType.arrived,
  'handedOver' => NotificationType.handedOver,
  'completed' => NotificationType.completed,
  'cancelled' => NotificationType.cancelled,
  _ => null,
};

/// Le destinataire accepte-t-il ce type ? (préférences US-009)
bool allowedByPreferences(NotificationType t, NotificationPreferences p) =>
    t == NotificationType.message || p.isEnabled(t.category);
