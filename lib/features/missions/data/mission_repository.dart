import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;

import '../../collection/data/collection_repository.dart';
import '../../collection/domain/collection_request.dart';

/// Mission déjà prise par un autre collecteur (verrou, US-044).
class MissionTaken implements Exception {
  const MissionTaken();
}

/// Motifs d'échec sur place (US-053).
enum NoShowReason { citizenAbsent, addressNotFound }

/// Missions vues du collecteur : les demandes `collections/{id}`.
abstract interface class MissionRepository {
  /// Demandes ouvertes (sans collecteur) : liste « disponibles ».
  Stream<List<CollectionRequest>> watchOpen();

  /// Demandes proposées à ce collecteur par la recherche automatique.
  Stream<List<CollectionRequest>> watchProposedTo(String uid);

  /// Missions acceptées par ce collecteur (en cours et historique).
  Stream<List<CollectionRequest>> watchMine(String uid);

  /// Acceptation verrouillée : le premier qui accepte l'emporte.
  Future<void> accept(String id, String uid);

  /// Refus (ou délai de 60 s dépassé) : la recherche reprend sans lui.
  Future<void> refuse(String id, String uid);

  /// En route → arrivé → en cours, horodatés (US-047).
  Future<void> advance(String id, CollectionStatus next);

  /// Photo preuve liée à la mission (US-048).
  Future<void> saveProof(String id, String uid, Uint8List jpeg);

  /// Citoyen absent / adresse introuvable : ticket + annulation sans
  /// pénalité pour le collecteur (US-053).
  Future<void> reportNoShow(
    CollectionRequest r,
    String uid,
    NoShowReason reason,
    String note,
    Uint8List? photo,
  );
}

class FirestoreMissionRepository implements MissionRepository {
  FirestoreMissionRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('collections');

  static Map<String, Object> _history(CollectionStatus s) => {
    'status': s.name,
    'at': Timestamp.now(),
  };

  List<CollectionRequest> _map(QuerySnapshot<Map<String, dynamic>> s) =>
      s.docs.map(FirestoreCollectionRepository.fromDoc).toList();

  @override
  Stream<List<CollectionRequest>> watchOpen() => _col
      .where(
        'status',
        whereIn: [CollectionStatus.searching.name, CollectionStatus.noCollector.name],
      )
      .limit(200)
      .snapshots()
      .map(_map);

  @override
  Stream<List<CollectionRequest>> watchProposedTo(String uid) => _col
      .where('proposedCollectorUid', isEqualTo: uid)
      .where('status', isEqualTo: CollectionStatus.proposed.name)
      .snapshots()
      .map(_map);

  @override
  Stream<List<CollectionRequest>> watchMine(String uid) =>
      _col.where('collectorUid', isEqualTo: uid).snapshots().map((s) {
        final list = _map(s)..sort((a, b) => b.slot.start.compareTo(a.slot.start));
        return list;
      });

  @override
  Future<void> accept(String id, String uid) => _db.runTransaction((tx) async {
    final ref = _col.doc(id);
    final snap = await tx.get(ref);
    if (!snap.exists) throw const MissionTaken();
    final r = FirestoreCollectionRepository.fromDoc(snap);
    final free =
        r.status == CollectionStatus.searching ||
        r.status == CollectionStatus.noCollector ||
        (r.status == CollectionStatus.proposed && r.proposedCollectorUid == uid);
    if (!free || r.collectorUid != null) throw const MissionTaken();
    tx.update(ref, {
      'status': CollectionStatus.accepted.name,
      'collectorUid': uid,
      'proposedCollectorUid': null,
      'acceptedAt': FieldValue.serverTimestamp(),
      'statusHistory': FieldValue.arrayUnion([_history(CollectionStatus.accepted)]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  @override
  Future<void> refuse(String id, String uid) => _col.doc(id).update({
    'status': CollectionStatus.searching.name,
    'proposedCollectorUid': null,
    'refusedBy': FieldValue.arrayUnion([uid]),
    'statusHistory': FieldValue.arrayUnion([_history(CollectionStatus.searching)]),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> advance(String id, CollectionStatus next) => _col.doc(id).update({
    'status': next.name,
    '${next.name}At': FieldValue.serverTimestamp(),
    'statusHistory': FieldValue.arrayUnion([_history(next)]),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> saveProof(String id, String uid, Uint8List jpeg) async {
    final batch = _db.batch()
      ..set(_col.doc(id).collection('attachments').doc('proof'), {
        'uid': uid,
        'data': base64Encode(jpeg),
        'takenAt': FieldValue.serverTimestamp(),
      })
      ..update(_col.doc(id), {'hasProof': true, 'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  @override
  Future<void> reportNoShow(
    CollectionRequest r,
    String uid,
    NoShowReason reason,
    String note,
    Uint8List? photo,
  ) => _db.runTransaction((tx) async {
    final counter = _db.collection('slotCounters').doc('${r.place.zoneId}__${r.slot.id}');
    final c = await tx.get(counter);
    final count = (c.data()?['count'] as num?)?.toInt() ?? 1;
    final ticket = _db.collection('tickets').doc();
    tx.set(ticket, {
      'collectionId': r.id,
      'reporterUid': uid,
      'reporterRole': 'collector',
      'reason': reason.name,
      'description': note.trim(),
      'photoCount': photo == null ? 0 : 1,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (photo != null) {
      tx.set(ticket.collection('photos').doc('0'), {'uid': uid, 'data': base64Encode(photo)});
    }
    tx.set(counter, {'count': count > 0 ? count - 1 : 0, 'zoneId': r.place.zoneId});
    tx.update(_col.doc(r.id), {
      'status': CollectionStatus.cancelled.name,
      'cancelledBy': 'collector',
      'cancelReason': reason.name,
      'noShowTicketId': ticket.id,
      'statusHistory': FieldValue.arrayUnion([_history(CollectionStatus.cancelled)]),
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}

/// La photo preuve a-t-elle été prise ? (champ `hasProof` de la demande)
Stream<bool> watchHasProof(FirebaseFirestore db, String id) => db
    .collection('collections')
    .doc(id)
    .snapshots()
    .map((s) => s.data()?['hasProof'] as bool? ?? false);
