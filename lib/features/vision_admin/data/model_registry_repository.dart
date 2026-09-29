import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/model_version.dart';

/// Versions du modèle (`modelVersions`) et configuration (`config/vision`).
abstract interface class ModelRegistryRepository {
  /// Versions enregistrées, la version embarquée toujours incluse.
  Stream<List<ModelVersion>> watchVersions();
  Stream<VisionConfig> watchConfig();
  Future<void> addVersion(ModelVersion version);
  Future<void> saveConfig(VisionConfig config);
}

class FirestoreModelRegistryRepository implements ModelRegistryRepository {
  FirestoreModelRegistryRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _config => _db.collection('config').doc('vision');

  @override
  Stream<List<ModelVersion>> watchVersions() => _db.collection('modelVersions').snapshots().map((
    s,
  ) {
    final list = [
      for (final d in s.docs)
        ModelVersion.fromMap(
          d.id,
          d.data(),
          createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
        ),
    ];
    if (!list.any((v) => v.id == bundledModel.id)) list.insert(0, bundledModel);
    list.sort((a, b) => (a.createdAt ?? DateTime(2000)).compareTo(b.createdAt ?? DateTime(2000)));
    return list;
  });

  @override
  Stream<VisionConfig> watchConfig() =>
      _config.snapshots().map((s) => VisionConfig.fromMap(s.data()));

  @override
  Future<void> addVersion(ModelVersion v) => _db.collection('modelVersions').doc(v.id).set({
    ...v.toMap(),
    'createdAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> saveConfig(VisionConfig c) =>
      _config.set({...c.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
}
