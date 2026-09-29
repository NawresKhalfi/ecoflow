import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/waste_category.dart';

/// Catalogue des classes de déchets : `wasteCategories/{id}` (US-022).
abstract interface class CatalogRepository {
  /// Catalogue trié ; le catalogue par défaut tant que rien n'est publié.
  Stream<List<WasteCategory>> watch();
  Future<void> save(WasteCategory category);
  Future<void> delete(String id);

  /// Publie le catalogue par défaut (première installation).
  Future<void> seedDefaults();
}

class FirestoreCatalogRepository implements CatalogRepository {
  FirestoreCatalogRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('wasteCategories');

  @override
  Stream<List<WasteCategory>> watch() => _col.snapshots().map((s) {
    if (s.docs.isEmpty) return defaultCatalog;
    final list = [for (final d in s.docs) WasteCategory.fromMap(d.id, d.data())]
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  });

  @override
  Future<void> save(WasteCategory c) => _col.doc(c.id).set(c.toMap());

  @override
  Future<void> delete(String id) {
    if (id == otherCategoryId) {
      throw ArgumentError('La catégorie de repli « other » est obligatoire.');
    }
    return _col.doc(id).delete();
  }

  @override
  Future<void> seedDefaults() async {
    final batch = _db.batch();
    for (final c in defaultCatalog) {
      batch.set(_col.doc(c.id), c.toMap());
    }
    await batch.commit();
  }
}
