import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../estimation/application/estimation_providers.dart';
import '../../estimation/domain/estimate_record.dart';
import '../domain/collection_request.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/feedback.dart';
import '../domain/geo.dart';
import '../domain/matching.dart';
import '../domain/recurrence_rules.dart';
import '../domain/time_slot.dart';
import '../../tracking/application/tracking_providers.dart';
import '../../tracking/domain/app_notification.dart';
import 'collection_providers.dart';
import 'matching_service.dart';

/// Modification hors délai (moins d'1 h avant le créneau).
class TooLateToModify implements Exception {
  const TooLateToModify();
}

/// Actions du citoyen sur une demande (US-035 à US-041).
class CollectionActionsController extends ActionController {
  MatchResult? lastMatch;

  DateTime get _now => ref.read(clockProvider)();

  /// Changement de créneau et/ou d'instructions (jusqu'à 1 h avant).
  Future<bool> modify(CollectionRequest r, {TimeSlot? slot, String? instructions}) => run(() async {
    if (!r.canModify(_now)) throw const TooLateToModify();
    final after = CollectionRequest(
      id: r.id,
      citizenUid: r.citizenUid,
      estimateCode: r.estimateCode,
      place: r.place,
      slot: slot ?? r.slot,
      estimatedKg: r.estimatedKg,
      estimatedDt: r.estimatedDt,
      instructions: instructions ?? r.instructions,
      hasInstructionPhoto: r.hasInstructionPhoto,
      recurrence: r.recurrence,
    );
    final repo = ref.read(collectionRepositoryProvider);
    await repo.modify(r, after);
    if (after.slot.id != r.slot.id) {
      final fresh = await repo.fetch(r.id);
      if (fresh != null) lastMatch = await runMatching(ref, fresh);
    }
  });

  /// Annulation ; pénalité seulement après acceptation d'un collecteur.
  Future<bool> cancel(CollectionRequest r, {bool stopSeries = false}) => run(() async {
    await ref.read(collectionRepositoryProvider).cancel(r);
    await notify(ref, toUid: r.collectorUid ?? r.proposedCollectorUid, type: NotificationType.cancelled, r: r);
    if (!stopSeries) await _scheduleNext(r);
  });

  /// Relance la recherche / rester en file d'attente (US-036).
  Future<bool> retryMatching(CollectionRequest r) => run(() async {
    lastMatch = await runMatching(ref, r);
  });

  /// Confirmation citoyen après la pesée du collecteur (US-039).
  Future<bool> confirmHandover(CollectionRequest r) => run(() async {
    await ref.read(collectionRepositoryProvider).confirmHandover(r.id);
    await notify(ref, toUid: r.collectorUid, type: NotificationType.completed, r: r);
    await _scheduleNext(r);
  });

  /// Arrête une série récurrente (US-037).
  Future<bool> stopRecurrence(CollectionRequest r) => run(
    () => ref.read(firestoreProvider).collection('collections').doc(r.id).update({
      'recurrence': Recurrence.none.name,
    }),
  );

  Future<bool> rate(CollectionRequest r, int stars, String comment) => run(() async {
    final collector = r.collectorUid;
    if (collector == null) throw StateError('no collector');
    await ref
        .read(feedbackRepositoryProvider)
        .rate(
          collectionId: r.id,
          citizenUid: r.citizenUid,
          collectorUid: collector,
          stars: stars,
          comment: comment,
        );
  });

  Future<bool> report(
    CollectionRequest r,
    ProblemReason reason,
    String description,
    List<Uint8List> photos,
  ) => run(() async {
    await ref
        .read(feedbackRepositoryProvider)
        .report(
          collectionId: r.id,
          reporterUid: ref.read(currentUidProvider)!,
          reason: reason,
          description: description,
          photos: photos,
        );
  });

  /// Collecte récurrente : crée l'occurrence suivante avec une nouvelle
  /// estimation (le code de remise est à usage unique).
  Future<void> _scheduleNext(CollectionRequest r) async {
    final next = nextOccurrence(r.slot, r.recurrence);
    if (next == null) return;
    final estimates = ref.read(estimateRepositoryProvider);
    final previous = await estimates.fetch(r.estimateCode);
    if (previous == null) return;
    final code = await estimates.create(
      EstimateRecord(
        code: '',
        citizenUid: r.citizenUid,
        lines: previous.lines,
        confidence: previous.confidence,
        priceScaleId: previous.priceScaleId,
        container: previous.container,
      ),
    );
    final repo = ref.read(collectionRepositoryProvider);
    final id = await repo.create(
      CollectionRequest(
        id: '',
        citizenUid: r.citizenUid,
        estimateCode: code,
        place: r.place,
        slot: next,
        estimatedKg: r.estimatedKg,
        estimatedDt: r.estimatedDt,
        instructions: r.instructions,
        recurrence: r.recurrence,
        seriesId: r.seriesId ?? r.id,
      ),
    );
    final created = await repo.fetch(id);
    if (created != null) await runMatching(ref, created);
  }
}

final collectionActionsControllerProvider =
    NotifierProvider.autoDispose<CollectionActionsController, AsyncValue<void>>(
      CollectionActionsController.new,
    );

/// Disponibilité du collecteur pour la recherche (strict minimum de l'epic 4 ;
/// zone de travail et missions complètes : epic 5).
class PresenceController extends ActionController {
  Future<bool> setOnline(bool online) => run(() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    final pos = online ? await ref.read(locationServiceProvider).currentPosition() : null;
    if (online && pos == null) throw const LocationRequired();
    // Capacité du véhicule déclaré (US-054), 200 kg par défaut.
    final profile = await ref.read(firestoreProvider).collection('users').doc(uid).get();
    final capacity = ((profile.data()?['vehicle'] as Map?)?['capacityKg'] as num?)?.toDouble();
    await ref
        .read(presenceRepositoryProvider)
        .setOnline(
          uid,
          online: online,
          point: pos == null ? null : GeoPoint(pos.latitude, pos.longitude),
          capacityKg: capacity ?? 200,
        );
  });
}

class LocationRequired implements Exception {
  const LocationRequired();
}

final presenceControllerProvider =
    NotifierProvider.autoDispose<PresenceController, AsyncValue<void>>(PresenceController.new);

final myPresenceProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return ref.watch(presenceRepositoryProvider).watchOnline(uid);
});
