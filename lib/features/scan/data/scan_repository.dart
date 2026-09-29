import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/detection.dart';
import '../domain/scan_record.dart';
import '../domain/scan_rules.dart';
import '../domain/waste_category.dart';

/// Photo stockée : JPEG anonymisé encodé en base64.
typedef StoredPhoto = ({Uint8List jpeg, int width, int height});

abstract interface class ScanRepository {
  /// Enregistre le scan et ses photos ; renvoie l'identifiant créé.
  Future<String> save(
    ScanRecord scan,
    List<StoredPhoto> photos,
    List<WasteCategory> catalog, {
    required DateTime now,
  });

  /// Met à jour le résultat après corrections (US-016).
  Future<void> updateDetections(
    String scanId,
    List<Detection> detections,
    List<WasteCategory> catalog, {
    bool? trainingConsent,
  });

  /// Scans avec consentement ET corrections, pour l'export du jeu de données.
  Future<List<ScanRecord>> correctedForTraining({int limit = 200});

  Future<List<StoredPhoto>> photos(String scanId);

  /// Supprime les photos dont la durée de conservation est dépassée
  /// (US-021). Sans [uid] : tous les scans (administrateur). Renvoie le
  /// nombre de photos supprimées.
  Future<int> purgeExpired({String? uid, required DateTime now});
}

class FirestoreScanRepository implements ScanRepository {
  FirestoreScanRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _scans => _db.collection('scans');

  Map<String, dynamic> _summary(List<Detection> detections, List<WasteCategory> catalog) => {
    'detections': [for (final d in detections) d.toMap()],
    'counts': countByCategory(detections, catalog),
    'total': detections.length,
    'recyclability': estimateRecyclability(detections, catalog)?.level.name,
  };

  @override
  Future<String> save(
    ScanRecord s,
    List<StoredPhoto> photos,
    List<WasteCategory> catalog, {
    required DateTime now,
  }) async {
    final ref = _scans.doc();
    final expiresAt = Timestamp.fromDate(now.add(photoRetention));
    final batch = _db.batch();
    batch.set(ref, {
      'uid': s.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': expiresAt,
      'photoCount': photos.length,
      'originalDetections': [for (final d in s.originalDetections) d.toMap()],
      ..._summary(s.detections, catalog),
      'corrections': s.corrections.toMap(),
      'corrected': s.corrections.hasChanges,
      'modelVersionId': s.modelVersionId,
      'threshold': s.threshold,
      'inferenceMs': s.inferenceMs,
      'trainingConsent': s.trainingConsent,
    });
    for (final (i, p) in photos.indexed) {
      batch.set(ref.collection('photos').doc('$i'), {
        'uid': s.uid,
        'data': base64Encode(p.jpeg),
        'width': p.width,
        'height': p.height,
        'expiresAt': expiresAt,
      });
    }
    await batch.commit();
    return ref.id;
  }

  @override
  Future<void> updateDetections(
    String scanId,
    List<Detection> detections,
    List<WasteCategory> catalog, {
    bool? trainingConsent,
  }) async {
    final ref = _scans.doc(scanId);
    final snap = await ref.get();
    final original = [
      for (final m in (snap.data()?['originalDetections'] as List? ?? const []))
        Detection.fromMap(m as Map),
    ];
    final corrections = ScanRecord(
      id: scanId,
      uid: '',
      photoCount: 0,
      detections: detections,
      originalDetections: original,
      modelVersionId: '',
      threshold: 0,
    ).corrections;
    final data = {
      ..._summary(detections, catalog),
      'corrections': corrections.toMap(),
      'corrected': corrections.hasChanges,
      'correctedAt': FieldValue.serverTimestamp(),
      'trainingConsent': ?trainingConsent,
    };
    // Suppression préalable de la carte des comptes : elle est remplacée,
    // jamais fusionnée avec l'ancienne.
    final batch = _db.batch()
      ..update(ref, {'counts': FieldValue.delete()})
      ..update(ref, data);
    await batch.commit();
  }

  static ScanRecord _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    List<Detection> list(String k) => [
      for (final x in (m[k] as List? ?? const [])) Detection.fromMap(x as Map),
    ];
    return ScanRecord(
      id: d.id,
      uid: m['uid'] as String? ?? '',
      photoCount: (m['photoCount'] as num?)?.toInt() ?? 0,
      detections: list('detections'),
      originalDetections: list('originalDetections'),
      modelVersionId: m['modelVersionId'] as String? ?? '',
      threshold: (m['threshold'] as num?)?.toDouble() ?? defaultConfidenceThreshold,
      inferenceMs: (m['inferenceMs'] as num?)?.toInt(),
      trainingConsent: m['trainingConsent'] as bool? ?? false,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<List<ScanRecord>> correctedForTraining({int limit = 200}) async {
    final q = await _scans
        .where('trainingConsent', isEqualTo: true)
        .where('corrected', isEqualTo: true)
        .limit(limit)
        .get();
    return q.docs.map(_fromDoc).toList();
  }

  @override
  Future<List<StoredPhoto>> photos(String scanId) async {
    final q = await _scans.doc(scanId).collection('photos').get();
    final docs = q.docs.toList()..sort((a, b) => int.parse(a.id).compareTo(int.parse(b.id)));
    return [
      for (final d in docs)
        (
          jpeg: base64Decode(d.data()['data'] as String),
          width: (d.data()['width'] as num).toInt(),
          height: (d.data()['height'] as num).toInt(),
        ),
    ];
  }

  @override
  Future<int> purgeExpired({String? uid, required DateTime now}) async {
    final cutoff = Timestamp.fromDate(now);
    // Filtre de date côté client pour l'utilisateur : évite un index composite.
    final scans = uid == null
        ? await _scans.where('expiresAt', isLessThan: cutoff).get()
        : await _scans.where('uid', isEqualTo: uid).get();
    var count = 0;
    for (final scan in scans.docs) {
      final expires = scan.data()['expiresAt'] as Timestamp?;
      if (expires == null ||
          expires.compareTo(cutoff) >= 0 ||
          scan.data()['photosPurged'] == true) {
        continue;
      }
      final photos = await scan.reference.collection('photos').get();
      final batch = _db.batch();
      for (final p in photos.docs) {
        batch.delete(p.reference);
      }
      batch.update(scan.reference, {'photosPurged': true});
      await batch.commit();
      count += photos.docs.length;
    }
    return count;
  }
}
