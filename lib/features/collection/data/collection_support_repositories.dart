import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:flutter/widgets.dart' show Locale;
import 'package:geocoding/geocoding.dart';

import '../domain/feedback.dart';
import '../domain/geo.dart';
import '../domain/matching.dart';
import '../domain/service_zone.dart';

/// Disponibilité des collecteurs : `collectorPresence/{uid}` (position
/// arrondie à ~1 km) et note moyenne `collectorStats/{uid}`.
abstract interface class PresenceRepository {
  Future<List<CollectorCandidate>> onlineCollectors();
  Stream<bool> watchOnline(String uid);
  Future<void> setOnline(String uid, {required bool online, GeoPoint? point, double? capacityKg});

  /// Zone de travail (US-042) et capacité du véhicule (US-054).
  Future<void> setWorkZone(String uid, {required GeoPoint center, required double radiusKm});
  Future<void> setCapacity(String uid, double capacityKg);
  Stream<Map<String, dynamic>> watch(String uid);
}

class FirestorePresenceRepository implements PresenceRepository {
  FirestorePresenceRepository(this._db);
  final FirebaseFirestore _db;

  @override
  Future<List<CollectorCandidate>> onlineCollectors() async {
    final q = await _db.collection('collectorPresence').where('online', isEqualTo: true).get();
    final result = <CollectorCandidate>[];
    for (final d in q.docs) {
      final point = GeoPoint.fromMap(d.data()['point']);
      if (point == null) continue;
      final stats = (await _db.collection('collectorStats').doc(d.id).get()).data();
      result.add(
        CollectorCandidate(
          uid: d.id,
          point: point,
          capacityKg: (d.data()['capacityKg'] as num?)?.toDouble() ?? 0,
          rating: (stats?['ratingAvg'] as num?)?.toDouble() ?? 0,
          ratingCount: (stats?['ratingCount'] as num?)?.toInt() ?? 0,
          zoneCenter: GeoPoint.fromMap((d.data()['workZone'] as Map?)?['center']),
          zoneRadiusKm: ((d.data()['workZone'] as Map?)?['radiusKm'] as num?)?.toDouble(),
        ),
      );
    }
    return result;
  }

  @override
  Stream<bool> watchOnline(String uid) => _db
      .collection('collectorPresence')
      .doc(uid)
      .snapshots()
      .map((s) => s.data()?['online'] as bool? ?? false);

  @override
  Future<void> setOnline(String uid, {required bool online, GeoPoint? point, double? capacityKg}) =>
      _db.collection('collectorPresence').doc(uid).set({
        'online': online,
        // Position partagée seulement en ligne (US-042).
        'point': online && point != null ? point.rounded().toMap() : FieldValue.delete(),
        'capacityKg': ?capacityKg,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> setWorkZone(String uid, {required GeoPoint center, required double radiusKm}) =>
      _db.collection('collectorPresence').doc(uid).set({
        'workZone': {'center': center.rounded().toMap(), 'radiusKm': radiusKm},
      }, SetOptions(merge: true));

  @override
  Future<void> setCapacity(String uid, double capacityKg) => _db
      .collection('collectorPresence')
      .doc(uid)
      .set({'capacityKg': capacityKg}, SetOptions(merge: true));

  @override
  Stream<Map<String, dynamic>> watch(String uid) =>
      _db.collection('collectorPresence').doc(uid).snapshots().map((s) => s.data() ?? const {});
}

/// Notes (US-040) et signalements (US-041).
abstract interface class FeedbackRepository {
  /// Une seule note par collecte (identifiant = id de la collecte).
  Future<void> rate({
    required String collectionId,
    required String citizenUid,
    required String collectorUid,
    required int stars,
    required String comment,
  });

  Future<String> report({
    required String collectionId,
    required String reporterUid,
    required ProblemReason reason,
    required String description,
    List<Uint8List> photos,
  });
}

class FirestoreFeedbackRepository implements FeedbackRepository {
  FirestoreFeedbackRepository(this._db);
  final FirebaseFirestore _db;

  @override
  Future<void> rate({
    required String collectionId,
    required String citizenUid,
    required String collectorUid,
    required int stars,
    required String comment,
  }) async {
    if (!isValidRating(stars)) throw ArgumentError.value(stars, 'stars');
    await _db.runTransaction((tx) async {
      final ratingRef = _db.collection('ratings').doc(collectionId);
      if ((await tx.get(ratingRef)).exists) throw StateError('already rated');
      final statsRef = _db.collection('collectorStats').doc(collectorUid);
      final stats = (await tx.get(statsRef)).data();
      final next = addRating(
        (stats?['ratingAvg'] as num?)?.toDouble() ?? 0,
        (stats?['ratingCount'] as num?)?.toInt() ?? 0,
        stars,
      );
      tx.set(ratingRef, {
        'citizenUid': citizenUid,
        'collectorUid': collectorUid,
        'stars': stars,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(statsRef, {'ratingAvg': next.avg, 'ratingCount': next.count});
      tx.update(_db.collection('collections').doc(collectionId), {'rated': true});
    });
  }

  @override
  Future<String> report({
    required String collectionId,
    required String reporterUid,
    required ProblemReason reason,
    required String description,
    List<Uint8List> photos = const [],
  }) async {
    final ref = _db.collection('tickets').doc();
    final batch = _db.batch()
      ..set(ref, {
        'collectionId': collectionId,
        'reporterUid': reporterUid,
        'reason': reason.name,
        'description': description.trim(),
        'photoCount': photos.length,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
    for (final (i, p) in photos.take(maxReportPhotos).indexed) {
      batch.set(ref.collection('photos').doc('$i'), {'uid': reporterUid, 'data': base64Encode(p)});
    }
    await batch.commit();
    return ref.id;
  }
}

/// Paramètres de collecte : `config/collection` (zones, capacité par créneau).
class CollectionConfig {
  const CollectionConfig({this.zones = defaultZones, this.slotCapacity = 10});

  final List<ServiceZone> zones;

  /// Nombre de demandes acceptées par créneau et par zone.
  final int slotCapacity;

  static CollectionConfig fromMap(Map<String, dynamic>? m) {
    if (m == null) return const CollectionConfig();
    final zones = [
      for (final e in (m['zones'] as Map? ?? const {}).entries)
        if (ServiceZone.fromMap('${e.key}', e.value as Map) case final z?) z,
    ];
    return CollectionConfig(
      zones: zones.isEmpty ? defaultZones : zones,
      slotCapacity: (m['slotCapacity'] as num?)?.toInt() ?? 10,
    );
  }
}

Stream<CollectionConfig> watchCollectionConfig(FirebaseFirestore db) => db
    .collection('config')
    .doc('collection')
    .snapshots()
    .map((s) => CollectionConfig.fromMap(s.data()));

/// Adresse lisible à partir d'une position (géocodeur natif, sans clé).
abstract interface class ReverseGeocoder {
  /// [languageCode] : langue de l'application (sinon celle du système).
  Future<String?> addressOf(GeoPoint p, {String? languageCode});
}

class NativeReverseGeocoder implements ReverseGeocoder {
  final _geocoding = Geocoding();

  @override
  Future<String?> addressOf(GeoPoint p, {String? languageCode}) async {
    try {
      final places = await _geocoding.placemarkFromCoordinates(
        p.lat,
        p.lng,
        locale: languageCode == null ? null : Locale(languageCode),
      );
      final pl = places.firstOrNull;
      if (pl == null) return null;
      final parts = [
        pl.street,
        pl.subLocality,
        pl.locality,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).toSet();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }
}
