import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../domain/collection_request.dart';
import 'collection_providers.dart';
import 'matching_service.dart';

/// Délai de réponse d'un collecteur à une proposition (US-044).
const proposalTimeoutForCitizen = Duration(seconds: 60);

/// Intervalle de relance de la file d'attente (US-036).
const queueRetryInterval = Duration(minutes: 2);

/// Surveillance côté citoyen (faute de backend) : relance la recherche après
/// un refus, expire les propositions sans réponse au bout de 60 s et
/// retente périodiquement les demandes en file d'attente.
class ProposalWatcher {
  ProposalWatcher(this._ref);

  final Ref _ref;
  final _inFlight = <String>{};
  final _lastQueueTry = <String, DateTime>{};

  DateTime get _now => _ref.read(clockProvider)();

  Future<void> check(List<CollectionRequest> requests) async {
    for (final r in requests) {
      if (_inFlight.contains(r.id)) continue;
      final expired =
          r.status == CollectionStatus.proposed &&
          r.proposedAt != null &&
          !_now.isBefore(r.proposedAt!.add(proposalTimeoutForCitizen));
      final queued =
          r.status == CollectionStatus.noCollector &&
          _now.difference(_lastQueueTry[r.id] ?? DateTime(2000)) >= queueRetryInterval;
      if (r.status != CollectionStatus.searching && !expired && !queued) continue;
      _inFlight.add(r.id);
      try {
        var target = r;
        if (expired) {
          // Pas de réponse en 60 s : considéré comme un refus.
          await _ref.read(firestoreProvider).collection('collections').doc(r.id).update({
            'status': CollectionStatus.searching.name,
            'proposedCollectorUid': null,
            'refusedBy': FieldValue.arrayUnion([r.proposedCollectorUid]),
          });
          target = await _ref.read(collectionRepositoryProvider).fetch(r.id) ?? r;
        }
        if (queued) _lastQueueTry[r.id] = _now;
        await runMatching(_ref, target);
      } catch (_) {
        // Réessayé au prochain passage.
      } finally {
        _inFlight.remove(r.id);
      }
    }
  }
}

/// À écouter dans l'espace citoyen : actif tant que l'application est ouverte.
final proposalWatcherProvider = Provider<void>((ref) {
  final watcher = ProposalWatcher(ref);
  ref.listen(
    myCollectionsProvider,
    (_, next) => watcher.check(next.value ?? const []),
    fireImmediately: true,
  );
  final timer = Timer.periodic(const Duration(seconds: 15), (_) {
    watcher.check(ref.read(myCollectionsProvider).value ?? const []);
  });
  ref.onDispose(timer.cancel);
});
