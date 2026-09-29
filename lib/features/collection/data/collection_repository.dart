import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;

import '../domain/collection_request.dart';
import '../domain/time_slot.dart';

/// Demandes de collecte : `collections/{id}` ; photo d'instructions dans
/// `collections/{id}/attachments/instructions` ; compteurs de créneaux
/// `slotCounters/{zone}__{slot}`.
abstract interface class CollectionRepository {
  /// Crée la demande, réserve le créneau et relie l'estimation (US-031 à 033).
  Future<String> create(CollectionRequest r, {Uint8List? instructionPhoto});
  Stream<List<CollectionRequest>> watchMine(String uid);
  Stream<CollectionRequest?> watch(String id);
  Future<CollectionRequest?> fetch(String id);

  /// Nombre de demandes par créneau dans une zone.
  Stream<Map<String, int>> watchSlotCounts(String zoneId);

  /// Résultat de la recherche de collecteur (US-034, US-036).
  Future<void> setMatch(String id, {required String? collectorUid, required double radiusKm});

  /// Modification : lieu, créneau, instructions ; relance la recherche (US-035).
  Future<void> modify(CollectionRequest before, CollectionRequest after);
  Future<void> cancel(CollectionRequest r);

  /// Le citoyen confirme la remise validée par le collecteur (US-039).
  Future<void> confirmHandover(String id);
  Future<Uint8List?> instructionPhoto(String id);
}

class FirestoreCollectionRepository implements CollectionRepository {
  FirestoreCollectionRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('collections');
  DocumentReference<Map<String, dynamic>> _counter(String zone, String slot) =>
      _db.collection('slotCounters').doc('${zone}__$slot');

  static Map<String, Object> _historyEntry(CollectionStatus s) => {
    'status': s.name,
    'at': Timestamp.now(),
  };

  static CollectionRequest fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return CollectionRequest(
      id: d.id,
      citizenUid: m['citizenUid'] as String? ?? '',
      estimateCode: m['estimateCode'] as String? ?? '',
      place: CollectionPlace.fromMap(m['place'] as Map? ?? const {}),
      slot: TimeSlot.fromId(m['slotId'] as String? ?? '') ?? TimeSlot(DateTime(2000), 8, 10),
      estimatedKg: (m['estimatedKg'] as num?)?.toDouble() ?? 0,
      estimatedDt: (m['estimatedDt'] as num?)?.toDouble() ?? 0,
      instructions: m['instructions'] as String? ?? '',
      hasInstructionPhoto: m['hasInstructionPhoto'] as bool? ?? false,
      status: CollectionStatus.fromName(m['status'] as String?),
      proposedCollectorUid: m['proposedCollectorUid'] as String?,
      collectorUid: m['collectorUid'] as String?,
      refusedBy: (m['refusedBy'] as List? ?? const []).cast<String>(),
      searchRadiusKm: (m['searchRadiusKm'] as num?)?.toDouble(),
      recurrence:
          Recurrence.values.where((r) => r.name == m['recurrence']).firstOrNull ?? Recurrence.none,
      seriesId: m['seriesId'] as String?,
      lateCancellation: m['lateCancellation'] as bool? ?? false,
      rated: m['rated'] as bool? ?? false,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _placeAndSlot(CollectionRequest r) => {
    'place': r.place.toMap(),
    'zoneId': r.place.zoneId,
    'slotId': r.slot.id,
    'slotStart': Timestamp.fromDate(r.slot.start),
    'instructions': r.instructions.trim(),
    'hasInstructionPhoto': r.hasInstructionPhoto,
  };

  @override
  Future<String> create(CollectionRequest r, {Uint8List? instructionPhoto}) async {
    final ref = _col.doc();
    await _db.runTransaction((tx) async {
      final counter = _counter(r.place.zoneId, r.slot.id);
      final current = await tx.get(counter);
      tx.set(counter, {
        'count': ((current.data()?['count'] as num?)?.toInt() ?? 0) + 1,
        'zoneId': r.place.zoneId,
      });
      tx.set(ref, {
        'citizenUid': r.citizenUid,
        'estimateCode': r.estimateCode,
        ..._placeAndSlot(r),
        'hasInstructionPhoto': instructionPhoto != null,
        'estimatedKg': r.estimatedKg,
        'estimatedDt': r.estimatedDt,
        'status': CollectionStatus.searching.name,
        'refusedBy': <String>[],
        'recurrence': r.recurrence.name,
        'seriesId': r.seriesId ?? (r.recurrence == Recurrence.none ? null : ref.id),
        'lateCancellation': false,
        'rated': false,
        'statusHistory': [_historyEntry(CollectionStatus.searching)],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.update(_db.collection('estimates').doc(r.estimateCode), {'requestId': ref.id});
    });
    if (instructionPhoto != null) {
      await ref.collection('attachments').doc('instructions').set({
        'uid': r.citizenUid,
        'data': base64Encode(instructionPhoto),
      });
    }
    return ref.id;
  }

  @override
  Stream<List<CollectionRequest>> watchMine(String uid) =>
      _col.where('citizenUid', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map(fromDoc).toList()
          ..sort((a, b) => b.slot.start.compareTo(a.slot.start));
        return list;
      });

  @override
  Stream<CollectionRequest?> watch(String id) =>
      _col.doc(id).snapshots().map((s) => s.exists ? fromDoc(s) : null);

  @override
  Future<CollectionRequest?> fetch(String id) async {
    final s = await _col.doc(id).get();
    return s.exists ? fromDoc(s) : null;
  }

  @override
  Stream<Map<String, int>> watchSlotCounts(String zoneId) => _db
      .collection('slotCounters')
      .where('zoneId', isEqualTo: zoneId)
      .snapshots()
      .map(
        (s) => {
          for (final d in s.docs) d.id.split('__').last: (d.data()['count'] as num?)?.toInt() ?? 0,
        },
      );

  @override
  Future<void> setMatch(String id, {required String? collectorUid, required double radiusKm}) {
    final status = collectorUid == null ? CollectionStatus.noCollector : CollectionStatus.proposed;
    return _col.doc(id).update({
      'status': status.name,
      'proposedCollectorUid': collectorUid,
      'searchRadiusKm': radiusKm,
      'statusHistory': FieldValue.arrayUnion([_historyEntry(status)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> modify(CollectionRequest before, CollectionRequest after) =>
      _db.runTransaction((tx) async {
        final slotChanged =
            before.slot.id != after.slot.id || before.place.zoneId != after.place.zoneId;
        if (slotChanged) {
          final oldC = _counter(before.place.zoneId, before.slot.id);
          final newC = _counter(after.place.zoneId, after.slot.id);
          final oldSnap = await tx.get(oldC);
          final newSnap = await tx.get(newC);
          final oldCount = (oldSnap.data()?['count'] as num?)?.toInt() ?? 1;
          final newCount = (newSnap.data()?['count'] as num?)?.toInt() ?? 0;
          tx.set(oldC, {'count': oldCount > 0 ? oldCount - 1 : 0, 'zoneId': before.place.zoneId});
          tx.set(newC, {'count': newCount + 1, 'zoneId': after.place.zoneId});
        }
        // Changement de lieu ou de créneau : la recherche repart de zéro.
        final relocated = slotChanged || before.place.point != after.place.point;
        tx.update(_col.doc(before.id), {
          ..._placeAndSlot(after),
          'hasInstructionPhoto': before.hasInstructionPhoto,
          if (relocated) ...{
            'status': CollectionStatus.searching.name,
            'proposedCollectorUid': null,
            'statusHistory': FieldValue.arrayUnion([_historyEntry(CollectionStatus.searching)]),
          },
          'modifiedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  @override
  Future<void> cancel(CollectionRequest r) => _db.runTransaction((tx) async {
    final counter = _counter(r.place.zoneId, r.slot.id);
    final snap = await tx.get(counter);
    final count = (snap.data()?['count'] as num?)?.toInt() ?? 1;
    tx.set(counter, {'count': count > 0 ? count - 1 : 0, 'zoneId': r.place.zoneId});
    tx.update(_col.doc(r.id), {
      'status': CollectionStatus.cancelled.name,
      'lateCancellation': r.cancellationPenalty,
      'statusHistory': FieldValue.arrayUnion([_historyEntry(CollectionStatus.cancelled)]),
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  @override
  Future<void> confirmHandover(String id) => _col.doc(id).update({
    'status': CollectionStatus.completed.name,
    'statusHistory': FieldValue.arrayUnion([_historyEntry(CollectionStatus.completed)]),
    'completedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<Uint8List?> instructionPhoto(String id) async {
    final d = await _col.doc(id).collection('attachments').doc('instructions').get();
    final data = d.data()?['data'] as String?;
    return data == null ? null : base64Decode(data);
  }
}
