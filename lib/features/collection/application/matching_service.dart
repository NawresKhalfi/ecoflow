import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

import '../../tracking/application/tracking_providers.dart';
import '../../tracking/domain/app_notification.dart';
import '../domain/collection_request.dart';
import '../domain/matching.dart';
import 'collection_providers.dart';

/// Recherche d'un collecteur pour une demande (US-034). Exécutée sur le
/// téléphone du citoyen faute de backend (plan Spark) ; même algorithme
/// déplaçable tel quel dans une Cloud Function.
Future<MatchResult> runMatching(Ref ref, CollectionRequest r) async {
  final candidates = await ref.read(presenceRepositoryProvider).onlineCollectors();
  final result = matchCollector(
    pickup: r.place.point,
    neededKg: r.estimatedKg,
    candidates: candidates.where((c) => c.uid != r.citizenUid).toList(),
    excluded: r.refusedBy.toSet(),
  );
  await ref
      .read(collectionRepositoryProvider)
      .setMatch(
        r.id,
        collectorUid: result.candidate?.uid,
        radiusKm: result.radiusKm,
        at: ref.read(clockProvider)(),
      );
  // Nouvelle mission proposée : alerte immédiate du collecteur (US-066).
  if (result.candidate != null) {
    await notify(ref, toUid: result.candidate!.uid, type: NotificationType.newMission, r: r);
  }
  return result;
}
