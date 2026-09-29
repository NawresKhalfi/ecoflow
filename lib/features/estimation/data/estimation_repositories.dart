import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/estimate_record.dart';
import '../domain/estimation_coefficients.dart';
import '../domain/handover_code.dart';
import '../domain/price_scale.dart';
import '../domain/weighing.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

/// Barèmes des prix : `priceScales/{id}` (US-027), jamais modifiés.
abstract interface class PriceScaleRepository {
  /// Barèmes du plus récent au plus ancien (date d'effet).
  Stream<List<PriceScale>> watch();
  Future<void> publish(PriceScale scale);
}

class FirestorePriceScaleRepository implements PriceScaleRepository {
  FirestorePriceScaleRepository(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<PriceScale>> watch() => _db.collection('priceScales').snapshots().map((s) {
    final list = [
      for (final d in s.docs)
        PriceScale.fromMap(
          d.id,
          d.data(),
          effectiveFrom: _date(d.data()['effectiveFrom']) ?? DateTime(2000),
          createdAt: _date(d.data()['createdAt']),
        ),
    ]..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    return list;
  });

  @override
  Future<void> publish(PriceScale s) => _db.collection('priceScales').add({
    ...s.toMap(),
    'effectiveFrom': Timestamp.fromDate(s.effectiveFrom),
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Coefficients d'estimation : `config/estimation` (US-030).
abstract interface class CoefficientsRepository {
  Stream<EstimationCoefficients> watch();

  /// Remplace les coefficients en gardant la version précédente.
  Future<void> save(EstimationCoefficients next, EstimationCoefficients previous);
}

class FirestoreCoefficientsRepository implements CoefficientsRepository {
  FirestoreCoefficientsRepository(this._db);
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('config').doc('estimation');

  @override
  Stream<EstimationCoefficients> watch() =>
      _doc.snapshots().map((s) => EstimationCoefficients.fromMap(s.data()));

  @override
  Future<void> save(EstimationCoefficients next, EstimationCoefficients previous) => _doc.set({
    ...next.toMap(),
    'previous': previous.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// Estimations et pesées : `estimates/{code}` (US-023 à US-029).
abstract interface class EstimateRepository {
  /// Enregistre l'estimation sous un nouveau code de pesée et le renvoie.
  Future<String> create(EstimateRecord record);
  Stream<List<EstimateRecord>> watchMine(String uid);
  Stream<EstimateRecord?> watch(String code);

  /// Lecture par le collecteur (accès par code uniquement, pas de liste).
  Future<EstimateRecord?> fetch(String code);
  Future<void> submitWeighing(
    String code,
    Map<String, double> actualKg,
    WeighingResult result,
    String collectorUid,
  );

  /// Pesées terminées, pour le recalibrage (administrateur).
  Future<List<EstimateRecord>> weighed({int limit = 500});
}

class FirestoreEstimateRepository implements EstimateRepository {
  FirestoreEstimateRepository(this._db, {String Function()? codeGenerator})
    : _newCode = codeGenerator ?? generateHandoverCode;

  final FirebaseFirestore _db;
  final String Function() _newCode;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('estimates');

  EstimateRecord _from(DocumentSnapshot<Map<String, dynamic>> d) => EstimateRecord.fromMap(
    d.id,
    d.data()!,
    createdAt: _date(d.data()!['createdAt']),
    weighedAt: _date(d.data()!['weighedAt']),
  );

  @override
  Future<String> create(EstimateRecord r) async {
    // Collision quasi impossible ; les règles refusent d'écraser un code
    // existant (création seule), on retente alors avec un autre.
    for (var attempt = 0; attempt < 3; attempt++) {
      final code = _newCode();
      try {
        await _db.runTransaction((tx) async {
          final ref = _col.doc(code);
          if ((await tx.get(ref)).exists) throw StateError('collision');
          tx.set(ref, {...r.toCreateMap(), 'createdAt': FieldValue.serverTimestamp()});
        });
        return code;
      } on StateError {
        continue;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied' || attempt == 2) rethrow;
      }
    }
    throw StateError('Impossible de générer un code unique');
  }

  @override
  Stream<List<EstimateRecord>> watchMine(String uid) =>
      _col.where('citizenUid', isEqualTo: uid).snapshots().map((s) {
        final list = s.docs.map(_from).toList()
          ..sort(
            (a, b) => (b.createdAt ?? DateTime(3000)).compareTo(a.createdAt ?? DateTime(3000)),
          );
        return list;
      });

  @override
  Stream<EstimateRecord?> watch(String code) =>
      _col.doc(code).snapshots().map((s) => s.exists ? _from(s) : null);

  @override
  Future<EstimateRecord?> fetch(String code) async {
    final s = await _col.doc(code).get();
    return s.exists ? _from(s) : null;
  }

  @override
  Future<void> submitWeighing(
    String code,
    Map<String, double> actualKg,
    WeighingResult result,
    String collectorUid,
  ) => _col.doc(code).update({
    'status': EstimateStatus.weighed.name,
    'actualKg': actualKg,
    'actualTotalKg': result.actualKg,
    'finalDt': result.finalDt,
    'collectorUid': collectorUid,
    'weighedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<List<EstimateRecord>> weighed({int limit = 500}) async {
    final q = await _col.where('status', isEqualTo: EstimateStatus.weighed.name).limit(limit).get();
    return q.docs.map(_from).toList();
  }
}
