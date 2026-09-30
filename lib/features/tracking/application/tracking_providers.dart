import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../collection/domain/collection_request.dart';
import '../../missions/application/missions_providers.dart';
import '../data/device_services.dart';
import '../data/tracking_repositories.dart';
import '../domain/app_notification.dart';
import '../domain/chat.dart';
import '../domain/eta.dart';

final notificationRepositoryProvider = Provider((ref) => NotificationRepository(ref.watch(firestoreProvider)));
final liveLocationRepositoryProvider = Provider((ref) => LiveLocationRepository(ref.watch(firestoreProvider)));
final chatRepositoryProvider = Provider((ref) => ChatRepository(ref.watch(firestoreProvider)));
final pushTokenRepositoryProvider = Provider((ref) => PushTokenRepository(ref.watch(firestoreProvider)));
final localNotifierProvider = Provider<LocalNotifier>((ref) => PluginLocalNotifier());
final pushTokenSourceProvider = Provider<PushTokenSource>((ref) => FirebasePushTokenSource());
final positionStreamProvider = Provider<PositionStreamSource>((ref) => GeolocatorPositionStream());

final myNotificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(notificationRepositoryProvider).watchMine(uid);
});

final unreadCountProvider = Provider<int>(
  (ref) => (ref.watch(myNotificationsProvider).value ?? const []).where((n) => !n.read).length,
);

final livePositionProvider = StreamProvider.family<LivePosition?, String>(
  (ref, id) => ref.watch(liveLocationRepositoryProvider).watch(id),
);

final chatProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, id) => ref.watch(chatRepositoryProvider).watch(id),
);

/// Envoi « au mieux » : une notification perdue ne doit jamais faire
/// échouer l'action métier qui la déclenche.
Future<void> notify(
  Ref ref, {
  required String? toUid,
  required NotificationType type,
  required CollectionRequest r,
  String preview = '',
}) async {
  final from = ref.read(authRepositoryProvider).currentUser?.uid;
  if (toUid == null || from == null || toUid == from) return;
  try {
    await ref.read(notificationRepositoryProvider).send(
      toUid: toUid,
      fromUid: from,
      type: type,
      collectionId: r.id,
      address: r.place.address,
      preview: preview,
    );
  } catch (e) {
    debugPrint('notify($type) failed: $e');
  }
}

/// Diffuse la position du collecteur toutes les 5 s pendant qu'il est en
/// route ou arrivé (US-063) ; l'efface dès que la mission passe à une autre
/// étape. À écouter dans l'espace collecteur.
final livePublisherProvider = Provider<void>((ref) {
  StreamSubscription<LivePosition>? sub;
  var active = <CollectionRequest>[];
  DateTime? last;

  void update(List<CollectionRequest> missions) {
    final uid = ref.read(currentUidProvider);
    final next = [
      for (final m in missions)
        if (m.status == CollectionStatus.onTheWay || m.status == CollectionStatus.arrived) m,
    ];
    final repo = ref.read(liveLocationRepositoryProvider);
    for (final gone in active.where((a) => !next.any((n) => n.id == a.id))) {
      repo.clear(gone.id).catchError((_) {});
    }
    active = next;
    if (active.isEmpty || uid == null) {
      sub?.cancel();
      sub = null;
      return;
    }
    sub ??= ref.read(positionStreamProvider).positions().listen((p) {
      final now = ref.read(clockProvider)();
      if (last != null && now.difference(last!) < liveUpdateInterval) return;
      last = now;
      for (final m in active) {
        repo.publish(m.id, uid, p).catchError((_) {});
      }
    });
  }

  ref.listen(myMissionsProvider, (_, next) => update(next.value ?? const []), fireImmediately: true);
  ref.onDispose(() => sub?.cancel());
});

/// Enregistre le jeton FCM de l'appareil (utilisé par la Cloud Function).
final pushRegistrationProvider = FutureProvider<bool>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return false;
  final token = await ref.read(pushTokenSourceProvider).token();
  if (token == null) return false;
  await ref.read(pushTokenRepositoryProvider).save(uid, token, kIsWeb ? 'web' : Platform.operatingSystem);
  return true;
});
