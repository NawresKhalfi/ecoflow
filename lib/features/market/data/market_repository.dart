import 'package:cloud_firestore/cloud_firestore.dart';

import '../../profile/domain/company_profile.dart';
import '../../recycler/domain/stock.dart';
import '../../tracking/domain/chat.dart';
import '../domain/market.dart';

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : (v is DateTime ? v : null);

/// Note d'une entreprise : `companyStats/{uid}` (US-101).
typedef CompanyRating = ({double avg, int count});

/// Signalement d'annonce : `listingReports/{id}` (US-103).
typedef ListingReport = ({
  String id,
  String listingId,
  String reporterUid,
  ReportReason reason,
  String text,
  bool resolved,
  DateTime? at,
});

/// Marketplace B2B : annonces, négociations, commandes, notes, signalements.
class MarketRepository {
  MarketRepository(this._db);
  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _listings => _db.collection('listings');
  CollectionReference<Map<String, dynamic>> get _deals => _db.collection('deals');
  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  Listing _listing(DocumentSnapshot<Map<String, dynamic>> d) =>
      Listing.fromMap(d.id, d.data()!, _date);

  // --- Annonces (US-094 à US-096) -----------------------------------------

  Stream<List<Listing>> watchOpen() => _listings
      .where('status', isEqualTo: ListingStatus.open.name)
      .snapshots()
      .map((s) => s.docs.map(_listing).toList()..sort((a, b) => a.deadline.compareTo(b.deadline)));

  Stream<List<Listing>> watchMine(String uid) => _listings
      .where('ownerUid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(_listing).toList()..sort(
              (a, b) => (b.createdAt ?? DateTime(3000)).compareTo(a.createdAt ?? DateTime(3000)),
            ),
      );

  Stream<Listing?> watchListing(String id) =>
      _listings.doc(id).snapshots().map((s) => s.exists ? _listing(s) : null);

  Future<String> saveListing(Listing l) async {
    if (l.id.isEmpty) {
      final ref = await _listings.add({...l.toMap(), 'createdAt': FieldValue.serverTimestamp()});
      return ref.id;
    }
    await _listings.doc(l.id).update(l.toMap()..remove('ownerUid'));
    return l.id;
  }

  Future<void> setListingStatus(String id, ListingStatus s) =>
      _listings.doc(id).update({'status': s.name});

  // --- Négociation (US-097, US-098) ---------------------------------------

  Deal _deal(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return Deal(
      id: d.id,
      listingId: m['listingId'] as String? ?? '',
      ownerUid: m['ownerUid'] as String? ?? '',
      counterpartUid: m['counterpartUid'] as String? ?? '',
      ownerName: m['ownerName'] as String? ?? '',
      counterpartName: m['counterpartName'] as String? ?? '',
      listingTitle: m['listingTitle'] as String? ?? '',
      lastMessage: m['lastMessage'] as String? ?? '',
      updatedAt: _date(m['updatedAt']),
    );
  }

  /// Ouvre (ou retrouve) le fil entre l'auteur de l'annonce et [me].
  Future<String> openDeal(Listing l, String me, String myName, String title) async {
    final ref = _deals.doc(Deal.idFor(l.id, me));
    // Le fil n'est lisible qu'une fois créé : on le crée d'abord (fusion).
    await ref.set({
      'listingId': l.id,
      'ownerUid': l.ownerUid,
      'counterpartUid': me,
      'members': [l.ownerUid, me],
      'ownerName': l.ownerName,
      'counterpartName': myName,
      'listingTitle': title,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return ref.id;
  }

  Stream<List<Deal>> watchDeals(String uid) => _deals
      .where('members', arrayContains: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(_deal).toList()..sort(
              (a, b) => (b.updatedAt ?? DateTime(3000)).compareTo(a.updatedAt ?? DateTime(3000)),
            ),
      );

  Stream<Deal?> watchDeal(String id) =>
      _deals.doc(id).snapshots().map((s) => s.exists ? _deal(s) : null);

  MarketMessage _message(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return MarketMessage(
      id: d.id,
      fromUid: m['fromUid'] as String? ?? '',
      kind: m['kind'] == 'proposal' ? MessageKind.proposal : MessageKind.text,
      text: m['text'] as String? ?? '',
      priceDtPerKg: (m['priceDtPerKg'] as num?)?.toDouble(),
      quantityKg: (m['quantityKg'] as num?)?.toDouble(),
      deliveryDays: (m['deliveryDays'] as num?)?.toInt(),
      status:
          ProposalStatus.values.where((s) => s.name == m['status']).firstOrNull ??
          ProposalStatus.pending,
      at: _date(m['at']),
    );
  }

  Stream<List<MarketMessage>> watchMessages(String dealId) => _deals
      .doc(dealId)
      .collection('messages')
      .snapshots()
      .map(
        (s) =>
            s.docs.map(_message).toList()
              ..sort((a, b) => (a.at ?? DateTime(3000)).compareTo(b.at ?? DateTime(3000))),
      );

  /// Message texte (coordonnées masquées) ou proposition chiffrée.
  Future<String> send(
    String dealId,
    String fromUid, {
    String text = '',
    double? price,
    double? quantity,
    int? days,
  }) async {
    final proposal = price != null;
    final clean = maskEmails(maskPhoneNumbers(text.trim()));
    final ref = _deals.doc(dealId).collection('messages').doc();
    final batch = _db.batch()
      ..set(ref, {
        'fromUid': fromUid,
        'kind': proposal ? MessageKind.proposal.name : MessageKind.text.name,
        'text': clean,
        if (proposal) ...{
          'priceDtPerKg': price,
          'quantityKg': quantity,
          'deliveryDays': days,
          'status': ProposalStatus.pending.name,
        },
        'at': FieldValue.serverTimestamp(),
      })
      ..update(_deals.doc(dealId), {
        'lastMessage': proposal ? '💼 $price DT/kg × $quantity kg' : clean,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    await batch.commit();
    return ref.id;
  }

  /// Réponse à une proposition. Acceptée : la commande est créée dans le
  /// même batch (identifiant = celui de la proposition, US-099).
  Future<String?> answer(Deal deal, Listing l, MarketMessage p, {required bool accept, required DateTime now}) async {
    final msg = _deals.doc(deal.id).collection('messages').doc(p.id);
    if (!accept) {
      await msg.update({'status': ProposalStatus.declined.name});
      return null;
    }
    final sellerIsOwner = l.type == ListingType.sell;
    final order = _orders.doc(p.id);
    final batch = _db.batch()
      ..update(msg, {'status': ProposalStatus.accepted.name})
      ..set(order, {
        'listingId': l.id,
        'dealId': deal.id,
        'sellerUid': sellerIsOwner ? deal.ownerUid : deal.counterpartUid,
        'buyerUid': sellerIsOwner ? deal.counterpartUid : deal.ownerUid,
        'sellerName': sellerIsOwner ? deal.ownerName : deal.counterpartName,
        'buyerName': sellerIsOwner ? deal.counterpartName : deal.ownerName,
        'parties': [deal.ownerUid, deal.counterpartUid],
        'material': l.material.name,
        'form': l.form.name,
        'grade': l.grade?.name,
        'quantityKg': p.quantityKg,
        'priceDtPerKg': p.priceDtPerKg,
        'deliveryDays': p.deliveryDays,
        'lotIds': sellerIsOwner ? l.lotIds : const <String>[],
        'number': orderNumber(p.id, now),
        'status': OrderStatus.confirmed.name,
        'payment': PaymentStatus.pending.name,
        'history': {OrderStatus.confirmed.name: FieldValue.serverTimestamp()},
        'createdAt': FieldValue.serverTimestamp(),
      });
    // Quantité entièrement couverte : l'annonce est clôturée.
    if ((p.quantityKg ?? 0) >= l.quantityKg - 1e-9) {
      batch.update(_listings.doc(l.id), {'status': ListingStatus.closed.name});
    }
    await batch.commit();
    return order.id;
  }

  Future<void> withdraw(String dealId, String messageId) => _deals
      .doc(dealId)
      .collection('messages')
      .doc(messageId)
      .update({'status': ProposalStatus.withdrawn.name});

  // --- Commandes (US-099 à US-101, US-104) --------------------------------

  MarketOrder _order(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return MarketOrder(
      id: d.id,
      listingId: m['listingId'] as String? ?? '',
      dealId: m['dealId'] as String? ?? '',
      sellerUid: m['sellerUid'] as String? ?? '',
      buyerUid: m['buyerUid'] as String? ?? '',
      sellerName: m['sellerName'] as String? ?? '',
      buyerName: m['buyerName'] as String? ?? '',
      material: materialFromName(m['material'] as String?),
      form: MaterialForm.values.where((f) => f.name == m['form']).firstOrNull ?? MaterialForm.raw,
      grade: QualityGrade.values.where((g) => g.name == m['grade']).firstOrNull,
      quantityKg: (m['quantityKg'] as num?)?.toDouble() ?? 0,
      priceDtPerKg: (m['priceDtPerKg'] as num?)?.toDouble() ?? 0,
      deliveryDays: (m['deliveryDays'] as num?)?.toInt() ?? 0,
      number: m['number'] as String? ?? d.id,
      status:
          OrderStatus.values.where((s) => s.name == m['status']).firstOrNull ??
          OrderStatus.confirmed,
      payment:
          PaymentStatus.values.where((s) => s.name == m['payment']).firstOrNull ??
          PaymentStatus.pending,
      lotIds: (m['lotIds'] as List? ?? const []).cast<String>(),
      sellerRating: (m['sellerRating'] as num?)?.toInt(),
      buyerRating: (m['buyerRating'] as num?)?.toInt(),
      createdAt: _date(m['createdAt']),
      originZones: ((m['origin'] as Map?)?['zones'] as List? ?? const []).cast<String>(),
      originPickups: ((m['origin'] as Map?)?['pickups'] as num?)?.toInt() ?? 0,
      history: {
        for (final e in (m['history'] as Map? ?? const {}).entries)
          for (final s in OrderStatus.values.where((s) => s.name == e.key))
            if (_date(e.value) case final at?) s: at,
      },
    );
  }

  Stream<List<MarketOrder>> watchOrders(String uid) => _orders
      .where('parties', arrayContains: uid)
      .snapshots()
      .map(
        (s) =>
            s.docs.map(_order).toList()..sort(
              (a, b) => (b.createdAt ?? DateTime(3000)).compareTo(a.createdAt ?? DateTime(3000)),
            ),
      );

  Stream<MarketOrder?> watchOrder(String id) =>
      _orders.doc(id).snapshots().map((s) => s.exists ? _order(s) : null);

  /// [origin] : instantané de traçabilité écrit par le vendeur à
  /// l'expédition (zones, collectes, lots), pour le certificat de l'acheteur.
  Future<void> setStatus(MarketOrder o, OrderStatus s, {Map<String, Object>? origin}) =>
      _orders.doc(o.id).update({
        'status': s.name,
        'history.${s.name}': FieldValue.serverTimestamp(),
        'origin': ?origin,
      });

  Future<void> setPayment(MarketOrder o, PaymentStatus p) =>
      _orders.doc(o.id).update({'payment': p.name});

  /// Note du partenaire (1 à 5), une fois la commande terminée.
  Future<void> rate(MarketOrder o, String me, int stars) => _db.runTransaction((tx) async {
    final target = o.isSeller(me) ? o.buyerUid : o.sellerUid;
    final statsRef = _db.collection('companyStats').doc(target);
    final stats = (await tx.get(statsRef)).data();
    final count = (stats?['ratingCount'] as num?)?.toInt() ?? 0;
    final avg = (stats?['ratingAvg'] as num?)?.toDouble() ?? 0;
    tx
      ..update(_orders.doc(o.id), {o.isSeller(me) ? 'buyerRating' : 'sellerRating': stars})
      ..set(statsRef, {'ratingCount': count + 1, 'ratingAvg': (avg * count + stars) / (count + 1)});
  });

  Stream<CompanyRating?> watchRating(String uid) => _db
      .collection('companyStats')
      .doc(uid)
      .snapshots()
      .map(
        (s) => s.exists
            ? (
                avg: (s.data()!['ratingAvg'] as num?)?.toDouble() ?? 0,
                count: (s.data()!['ratingCount'] as num?)?.toInt() ?? 0,
              )
            : null,
      );

  // --- Modération (US-103) ------------------------------------------------

  Future<void> report(String listingId, String uid, ReportReason reason, String text) =>
      _db.collection('listingReports').add({
        'listingId': listingId,
        'reporterUid': uid,
        'reason': reason.name,
        'text': text.trim(),
        'resolved': false,
        'at': FieldValue.serverTimestamp(),
      });

  Stream<List<ListingReport>> watchReports() => _db
      .collection('listingReports')
      .where('resolved', isEqualTo: false)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            (
              id: d.id,
              listingId: d.data()['listingId'] as String? ?? '',
              reporterUid: d.data()['reporterUid'] as String? ?? '',
              reason:
                  ReportReason.values.where((r) => r.name == d.data()['reason']).firstOrNull ??
                  ReportReason.other,
              text: d.data()['text'] as String? ?? '',
              resolved: false,
              at: _date(d.data()['at']),
            ),
        ],
      );

  Stream<List<Listing>> watchAll() => _listings.snapshots().map((s) => s.docs.map(_listing).toList());

  Future<void> resolveReport(String id) =>
      _db.collection('listingReports').doc(id).update({'resolved': true});
}

/// Matières suggérées pour un vendeur : stock disponible par matière.
Map<RecyclableMaterial, double> stockByMaterial(List<StockLot> lots) => {
  for (final e in stockSummary(lots).entries) e.key: totalKg(e.value),
};
