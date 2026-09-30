import 'package:cloud_firestore/cloud_firestore.dart';

import '../../missions/domain/deposit.dart';
import '../../profile/domain/company_profile.dart';
import '../domain/analytics.dart';
import '../domain/purchasing.dart';
import '../domain/reception.dart';
import '../domain/stock.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

/// Stocks du recycleur : `lots`, `stockMoves`, `productions` (US-080 à 087)
/// et conditions d'achat (`companies/{uid}.purchasing`).
class RecyclerRepository {
  RecyclerRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _lots => _db.collection('lots');
  CollectionReference<Map<String, dynamic>> get _moves => _db.collection('stockMoves');

  StockLot _lot(DocumentSnapshot<Map<String, dynamic>> d) =>
      StockLot.fromMap(d.id, d.data()!, _date);

  Stream<List<StockLot>> watchLots(String uid) => _lots
      .where('recyclerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => s.docs.map(_lot).toList()
          ..sort(
            (a, b) => (b.receivedAt ?? DateTime(3000)).compareTo(a.receivedAt ?? DateTime(3000)),
          ),
      );

  Stream<List<StockMove>> watchMoves(String uid) => _moves
      .where('recyclerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            StockMove(
              id: d.id,
              lotId: d.data()['lotId'] as String? ?? '',
              material: materialFromName(d.data()['material'] as String?),
              deltaKg: (d.data()['deltaKg'] as num?)?.toDouble() ?? 0,
              reason:
                  MoveReason.values.where((r) => r.name == d.data()['reason']).firstOrNull ??
                  MoveReason.adjust,
              note: d.data()['note'] as String? ?? '',
              at: _date(d.data()['at']),
            ),
        ]..sort((a, b) => (b.at ?? DateTime(3000)).compareTo(a.at ?? DateTime(3000))),
      );

  Map<String, dynamic> _move(
    String uid,
    String lotId,
    RecyclableMaterial m,
    double delta,
    MoveReason reason, [
    String note = '',
  ]) => {
    'recyclerUid': uid,
    'lotId': lotId,
    'material': m.name,
    'deltaKg': delta,
    'reason': reason.name,
    'note': note,
    'at': FieldValue.serverTimestamp(),
  };

  /// Réception d'un dépôt (US-080) : un lot par matière pesée, avec
  /// l'instantané de traçabilité du dépôt (US-084), dans un seul batch.
  Future<List<String>> receive(String uid, Deposit d, ReceptionInput input) async {
    final batch = _db.batch();
    final lotIds = <String>[];
    for (final e in input.kgByMaterial.entries.where((e) => e.value > 0)) {
      final ref = _lots.doc();
      lotIds.add(ref.id);
      batch
        ..set(ref, {
          ...StockLot(
            id: ref.id,
            recyclerUid: uid,
            material: e.key,
            grade: input.grade,
            initialKg: e.value,
            kg: e.value,
            depositId: d.id,
            collectorUid: d.collectorUid,
            collectorName: d.collectorName,
            zoneIds: d.zoneIds,
            missions: d.missions,
          ).toMap(),
          'receivedAt': FieldValue.serverTimestamp(),
        })
        ..set(_moves.doc(), _move(uid, ref.id, e.key, e.value, MoveReason.reception));
    }
    batch.update(_db.collection('deposits').doc(d.id), {
      'status': DepositStatus.confirmed.name,
      'note': input.note.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'receivedKg': {
        for (final e in input.kgByMaterial.entries)
          if (e.value > 0) e.key.name: e.value,
      },
      'quality': input.grade.name,
      'contaminationPct': input.contaminationPct,
      'lotIds': lotIds,
    });
    await batch.commit();
    return lotIds;
  }

  /// Sortie de stock (vente, perte, ajustement) avec contrôle du restant.
  Future<void> moveOut(String uid, StockLot lot, double kg, MoveReason reason, String note) =>
      _db.runTransaction((tx) async {
        final fresh = _lot(await tx.get(_lots.doc(lot.id)));
        if (kg <= 0 || kg > fresh.kg + 1e-9) throw InsufficientStock(fresh.kg);
        tx
          ..update(_lots.doc(lot.id), {'kg': fresh.kg - kg})
          ..set(_moves.doc(), _move(uid, lot.id, lot.material, -kg, reason, note));
      });

  /// Production (US-087) : consomme la matière (FIFO), crée le lot produit
  /// avec ses lots d'origine (traçabilité) et l'historise.
  Future<String> produce(String uid, List<StockLot> lots, ProductionInput p) =>
      _db.runTransaction((tx) async {
        final fresh = <StockLot>[
          for (final l in lots.where((l) => l.material == p.material && l.inStock))
            _lot(await tx.get(_lots.doc(l.id))),
        ];
        final taken = consumeFifo(fresh, p.material, p.inputKg);
        final out = _lots.doc();
        final inputs = [for (final (l, _) in taken) l];
        for (final (l, kg) in taken) {
          tx
            ..update(_lots.doc(l.id), {'kg': l.kg - kg})
            ..set(_moves.doc(), _move(uid, l.id, l.material, -kg, MoveReason.production));
        }
        tx
          ..set(out, {
            ...StockLot(
              id: out.id,
              recyclerUid: uid,
              material: p.material,
              grade: p.grade,
              form: p.form,
              source: LotSource.production,
              initialKg: p.outputKg,
              kg: p.outputKg,
              zoneIds: {for (final l in inputs) ...l.zoneIds}.toList(),
              inputLotIds: [for (final l in inputs) l.id],
              marketplace: p.marketplace,
            ).toMap(),
            'receivedAt': FieldValue.serverTimestamp(),
          })
          ..set(_moves.doc(), _move(uid, out.id, p.material, p.outputKg, MoveReason.production))
          ..set(_db.collection('productions').doc(), {
            'recyclerUid': uid,
            'material': p.material.name,
            'inputKg': p.inputKg,
            'outputKg': p.outputKg,
            'form': p.form.name,
            'grade': p.grade.name,
            'inputLotIds': [for (final l in inputs) l.id],
            'outputLotId': out.id,
            'at': FieldValue.serverTimestamp(),
          });
        return out.id;
      });

  Future<void> setMarketplace(StockLot lot, bool on) =>
      _lots.doc(lot.id).update({'marketplace': on});

  // --- Conditions d'achat (US-085) -----------------------------------------

  Stream<Purchasing> watchPurchasing(String uid) => _db
      .collection('companies')
      .doc(uid)
      .snapshots()
      .map((s) => purchasingFromMap(s.data()?['purchasing'] as Map?));

  Future<void> savePurchasing(String uid, Purchasing p) =>
      _db.collection('companies').doc(uid).update({'purchasing': purchasingToMap(p)});

  /// Recycleurs validés et leurs conditions, pour orienter les dépôts.
  Future<List<RecyclerOffer>> recyclerOffers() async {
    final q = await _db.collection('companies').where('status', isEqualTo: 'approved').get();
    return [
      for (final d in q.docs)
        (
          uid: d.id,
          name: d.data()['legalName'] as String? ?? '',
          city: d.data()['city'] as String? ?? '',
          purchasing: purchasingFromMap(d.data()['purchasing'] as Map?),
        ),
    ];
  }
}
