import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/offline_write.dart';
import '../../auth/application/action_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../collection/domain/collection_request.dart';
import '../../estimation/application/estimation_providers.dart';
import '../../estimation/domain/handover_code.dart';
import '../../estimation/domain/weighing.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/data/document_picker.dart';
import '../../tracking/application/tracking_providers.dart';
import '../../tracking/domain/app_notification.dart';
import '../data/mission_repository.dart';
import '../domain/mission_rules.dart';
import 'missions_providers.dart';

/// Code saisi différent du code du citoyen : pas de validation (US-050).
class WrongHandoverCode implements Exception {
  const WrongHandoverCode();
}

/// Photo preuve manquante avant clôture (US-048).
class ProofRequired implements Exception {
  const ProofRequired();
}

/// Poids réel manquant pour une matière.
class WeightsIncomplete implements Exception {
  const WeightsIncomplete();
}

/// Actions du collecteur sur une mission (US-044 à US-053).
class MissionActionsController extends ActionController {
  String get _uid => ref.read(currentUidProvider)!;
  MissionRepository get _repo => ref.read(missionRepositoryProvider);
  SyncTracker get _sync => ref.read(syncTrackerProvider.notifier);

  Future<bool> accept(CollectionRequest r) => run(() async {
    await _repo.accept(r.id, _uid);
    await notify(ref, toUid: r.citizenUid, type: NotificationType.assigned, r: r);
  });

  /// Refus explicite ou délai de 60 s dépassé.
  Future<bool> refuse(CollectionRequest r) => run(() => _repo.refuse(r.id, _uid));

  Future<bool> advance(CollectionRequest r) => run(() async {
    final next = nextStep(r.status);
    if (next == null) return;
    // Hors ligne (US-126) : l'étape est enregistrée localement et envoyée
    // au retour du réseau ; la notification suit la même file.
    await _sync.write(_repo.advance(r.id, next));
    final type = statusNotification(next.name);
    if (type != null) await _sync.write(notify(ref, toUid: r.citizenUid, type: type, r: r));
  });

  Future<bool> takeProof(CollectionRequest r, PickSource source) => run(() async {
    final f = await ref.read(documentPickerProvider).pick(source);
    if (f != null) await _sync.write(_repo.saveProof(r.id, _uid, f.bytes));
  });

  /// Clôture : le citoyen valide en donnant son code de remise ; la pesée
  /// est enregistrée et la mission attend sa confirmation (US-050).
  Future<bool> close(
    CollectionRequest r, {
    required String code,
    required Map<String, double?> actualKg,
    required bool hasProof,
  }) => run(() async {
    if (!hasProof) throw const ProofRequired();
    if (normalizeHandoverCode(code) != r.estimateCode) throw const WrongHandoverCode();
    final estimates = ref.read(estimateRepositoryProvider);
    final estimate = await estimates.fetch(r.estimateCode);
    if (estimate == null) throw const WrongHandoverCode();
    if (!isWeighingComplete(estimate.lines, actualKg)) throw const WeightsIncomplete();
    final actual = {for (final l in estimate.lines) l.categoryId: actualKg[l.categoryId]!};
    await _sync.write(
      estimates.submitWeighing(
        r.estimateCode,
        actual,
        compareWeighing(estimate.lines, actual),
        _uid,
      ),
    );
    await _sync.write(notify(ref, toUid: r.citizenUid, type: NotificationType.handedOver, r: r));
  });

  Future<bool> reportNoShow(
    CollectionRequest r,
    NoShowReason reason,
    String note,
    Uint8List? photo,
  ) => run(() async {
    await _repo.reportNoShow(r, _uid, reason, note, photo);
    await notify(ref, toUid: r.citizenUid, type: NotificationType.cancelled, r: r);
  });

  /// Photo facultative jointe au signalement.
  Future<Uint8List?> pickPhoto(PickSource source) async =>
      (await ref.read(documentPickerProvider).pick(source))?.bytes;
}

final missionActionsControllerProvider =
    NotifierProvider.autoDispose<MissionActionsController, AsyncValue<void>>(
      MissionActionsController.new,
    );
