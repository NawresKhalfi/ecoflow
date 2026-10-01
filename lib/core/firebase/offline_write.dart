import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import 'firebase_providers.dart';

/// Résultat d'une écriture tolérante au hors-ligne (US-126).
enum WriteOutcome { synced, queued }

/// Attend l'accusé du serveur au plus [grace]. Au-delà, l'écriture reste
/// dans la file locale de Firestore (déjà visible dans le cache) et sera
/// envoyée au retour du réseau : on rend la main à l'interface. Un refus
/// tardif du serveur (conflit : la mission a changé entre-temps) est remonté
/// à [onLateError] ; [onLateDone] signale la synchronisation.
Future<WriteOutcome> settleWrite(
  Future<void> write, {
  Duration grace = const Duration(seconds: 3),
  void Function(Object error)? onLateError,
  void Function()? onLateDone,
}) {
  final result = Completer<WriteOutcome>();
  var late = false;
  final timer = Timer(grace, () {
    late = true;
    if (!result.isCompleted) result.complete(WriteOutcome.queued);
  });
  write.then(
    (_) {
      timer.cancel();
      if (late) {
        onLateDone?.call();
      } else if (!result.isCompleted) {
        result.complete(WriteOutcome.synced);
      }
    },
    onError: (Object e, StackTrace st) {
      timer.cancel();
      if (late) {
        onLateError?.call(e);
      } else if (!result.isCompleted) {
        result.completeError(e, st);
      }
    },
  );
  return result.future;
}

/// Actions enregistrées hors ligne et pas encore confirmées par le serveur,
/// et refus survenus à la synchronisation.
class SyncState {
  const SyncState({this.pending = 0, this.conflicts = 0});
  final int pending;

  /// Compteur croissant : chaque nouveau refus déclenche un message.
  final int conflicts;
}

class SyncTracker extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();

  /// Écriture tolérante au hors-ligne suivie dans le bandeau de l'app.
  Future<WriteOutcome> write(Future<void> f) async {
    final outcome = await settleWrite(
      f,
      onLateDone: _settled,
      onLateError: (_) {
        _settled();
        state = SyncState(pending: state.pending, conflicts: state.conflicts + 1);
      },
    );
    if (outcome == WriteOutcome.queued) {
      state = SyncState(pending: state.pending + 1, conflicts: state.conflicts);
    }
    return outcome;
  }

  void _settled() => state = SyncState(
    pending: state.pending > 0 ? state.pending - 1 : 0,
    conflicts: state.conflicts,
  );
}

final syncTrackerProvider = NotifierProvider<SyncTracker, SyncState>(SyncTracker.new);

/// Hors ligne : le profil n'est servi que par le cache local.
final offlineProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(false);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .map((s) => s.metadata.isFromCache)
      .distinct();
});
