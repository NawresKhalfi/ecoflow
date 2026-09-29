import 'geo.dart';
import 'time_slot.dart';

/// Cycle de vie d'une demande. `accepted` → `arrived` sont pilotés par le
/// collecteur (epics 5 et 7).
enum CollectionStatus {
  searching,
  noCollector,
  proposed,
  accepted,
  onTheWay,
  arrived,
  handedOver,
  completed,
  cancelled;

  static CollectionStatus fromName(String? n) =>
      values.firstWhere((v) => v.name == n, orElse: () => CollectionStatus.searching);

  /// Étapes affichées sur la frise de suivi.
  int get step => switch (this) {
    searching || noCollector => 0,
    proposed || accepted => 1,
    onTheWay || arrived => 2,
    handedOver => 3,
    completed => 4,
    cancelled => -1,
  };

  bool get isOpen => this != completed && this != cancelled;

  /// Un collecteur s'est engagé : annuler entraîne une pénalité (US-035).
  bool get collectorCommitted => this == accepted || this == onTheWay || this == arrived;
}

enum Recurrence { none, weekly, monthly }

/// Lieu de collecte.
class CollectionPlace {
  const CollectionPlace({required this.point, required this.address, required this.zoneId});

  final GeoPoint point;
  final String address;
  final String zoneId;

  Map<String, dynamic> toMap() => {'point': point.toMap(), 'address': address, 'zoneId': zoneId};

  static CollectionPlace fromMap(Map m) => CollectionPlace(
    point: GeoPoint.fromMap(m['point']) ?? const GeoPoint(0, 0),
    address: m['address'] as String? ?? '',
    zoneId: m['zoneId'] as String? ?? '',
  );
}

/// Longueur maximale des instructions (US-033).
const maxInstructionsLength = 300;

/// Demande de collecte : `collections/{id}`.
class CollectionRequest {
  const CollectionRequest({
    required this.id,
    required this.citizenUid,
    required this.estimateCode,
    required this.place,
    required this.slot,
    required this.estimatedKg,
    required this.estimatedDt,
    this.instructions = '',
    this.hasInstructionPhoto = false,
    this.status = CollectionStatus.searching,
    this.proposedCollectorUid,
    this.collectorUid,
    this.refusedBy = const [],
    this.searchRadiusKm,
    this.recurrence = Recurrence.none,
    this.seriesId,
    this.lateCancellation = false,
    this.rated = false,
    this.createdAt,
  });

  final String id;
  final String citizenUid;

  /// Code de l'estimation (epic 3), aussi code de remise (US-039).
  final String estimateCode;
  final CollectionPlace place;
  final TimeSlot slot;
  final double estimatedKg;
  final double estimatedDt;
  final String instructions;
  final bool hasInstructionPhoto;
  final CollectionStatus status;
  final String? proposedCollectorUid;
  final String? collectorUid;
  final List<String> refusedBy;
  final double? searchRadiusKm;
  final Recurrence recurrence;
  final String? seriesId;
  final bool lateCancellation;
  final bool rated;
  final DateTime? createdAt;

  /// Modification jusqu'à 1 h avant le créneau, avant l'arrivée (US-035).
  bool canModify(DateTime now) =>
      (status.step <= 1 || status == CollectionStatus.noCollector) &&
      now.isBefore(slot.start.subtract(bookingLead));

  /// Annulation possible tant que les déchets ne sont pas remis.
  bool get canCancel => status.isOpen && status.step < 3;

  /// Pénalité seulement si un collecteur avait déjà accepté.
  bool get cancellationPenalty => status.collectorCommitted;

  bool get canRate => status == CollectionStatus.completed && !rated;
  bool get awaitingCitizenConfirmation => status == CollectionStatus.handedOver;
}
