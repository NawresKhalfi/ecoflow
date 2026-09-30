import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;

import '../../collection/domain/geo.dart';
import '../domain/app_notification.dart';
import '../domain/chat.dart';
import '../domain/eta.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

/// Boîte d'envoi des notifications : `notifications/{id}` (US-065/066).
class NotificationRepository {
  NotificationRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('notifications');

  Future<void> send({
    required String toUid,
    required String fromUid,
    required NotificationType type,
    required String collectionId,
    String address = '',
    String preview = '',
  }) => _col.add({
    'toUid': toUid,
    'fromUid': fromUid,
    'type': type.name,
    'collectionId': collectionId,
    'address': address,
    'preview': preview,
    'critical': type.critical,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
  });

  Stream<List<AppNotification>> watchMine(String uid) =>
      _col.where('toUid', isEqualTo: uid).limit(100).snapshots().map((s) {
        final list = [
          for (final d in s.docs)
            if (NotificationType.fromName(d.data()['type'] as String?) case final t?)
              AppNotification(
                id: d.id,
                toUid: uid,
                fromUid: d.data()['fromUid'] as String?,
                type: t,
                collectionId: d.data()['collectionId'] as String? ?? '',
                address: d.data()['address'] as String? ?? '',
                preview: d.data()['preview'] as String? ?? '',
                read: d.data()['read'] as bool? ?? false,
                createdAt: _date(d.data()['createdAt']),
              ),
        ]..sort((a, b) => (b.createdAt ?? DateTime(3000)).compareTo(a.createdAt ?? DateTime(3000)));
        return list;
      });

  Future<void> markRead(String id) => _col.doc(id).update({'read': true});

  Future<void> markAllRead(List<AppNotification> list) async {
    final batch = _db.batch();
    for (final n in list.where((n) => !n.read)) {
      batch.update(_col.doc(n.id), {'read': true});
    }
    await batch.commit();
  }
}

/// Position du collecteur pendant une mission : `liveLocations/{collectionId}`
/// (US-063). Supprimée à la fin : rien n'est conservé après la mission.
class LiveLocationRepository {
  LiveLocationRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String id) =>
      _db.collection('liveLocations').doc(id);

  Future<void> publish(String collectionId, String collectorUid, LivePosition p) =>
      _doc(collectionId).set({
        'collectorUid': collectorUid,
        'point': p.point.toMap(),
        'speedKmh': p.speedKmh,
        'at': Timestamp.fromDate(p.at),
      });

  Stream<LivePosition?> watch(String collectionId) => _doc(collectionId).snapshots().map((s) {
    final m = s.data();
    final point = GeoPoint.fromMap(m?['point']);
    if (m == null || point == null) return null;
    return LivePosition(
      point: point,
      at: _date(m['at']) ?? DateTime.now(),
      speedKmh: (m['speedKmh'] as num?)?.toDouble(),
    );
  });

  Future<void> clear(String collectionId) => _doc(collectionId).delete();
}

/// Messagerie de la collecte : `collections/{id}/messages` (US-067).
class ChatRepository {
  ChatRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String id) =>
      _db.collection('collections').doc(id).collection('messages');

  Stream<List<ChatMessage>> watch(String collectionId) => _col(collectionId)
      .orderBy('at')
      .limit(300)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            ChatMessage(
              id: d.id,
              fromUid: d.data()['fromUid'] as String? ?? '',
              text: d.data()['text'] as String? ?? '',
              at: _date(d.data()['at']),
            ),
        ],
      );

  Future<void> send(String collectionId, String fromUid, String text) => _col(collectionId).add({
    'fromUid': fromUid,
    'text': maskPhoneNumbers(text.trim()),
    'at': FieldValue.serverTimestamp(),
  });
}

/// Jetons FCM des appareils : `fcmTokens/{token}`, lus uniquement par la
/// Cloud Function d'envoi (plan Blaze).
class PushTokenRepository {
  PushTokenRepository(this._db);
  final FirebaseFirestore _db;

  Future<void> save(String uid, String token, String platform) => _db
      .collection('fcmTokens')
      .doc(token)
      .set({'uid': uid, 'platform': platform, 'updatedAt': FieldValue.serverTimestamp()});
}
