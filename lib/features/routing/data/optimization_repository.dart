import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;

import '../domain/optimization_config.dart';

/// Configuration : `config/optimization`, historique dans
/// `config/optimization/history/{id}` (US-062).
class OptimizationRepository {
  OptimizationRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('config').doc('optimization');

  Stream<OptimizationConfig> watch() =>
      _doc.snapshots().map((s) => OptimizationConfig.fromMap(s.data()));

  Stream<List<({OptimizationConfig config, DateTime? at, String by})>> watchHistory() => _doc
      .collection('history')
      .orderBy('at', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            (
              config: OptimizationConfig.fromMap(d.data()),
              at: (d.data()['at'] as Timestamp?)?.toDate(),
              by: d.data()['by'] as String? ?? '',
            ),
        ],
      );

  Future<void> publish(OptimizationConfig c, String adminUid) async {
    final batch = _db.batch()
      ..set(_doc, {...c.toMap(), 'updatedAt': FieldValue.serverTimestamp()})
      ..set(_doc.collection('history').doc(), {
        ...c.toMap(),
        'at': FieldValue.serverTimestamp(),
        'by': adminUid,
      });
    await batch.commit();
  }
}
