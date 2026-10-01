import 'package:ecoflow/features/market/data/market_documents.dart';
import 'package:ecoflow/features/market/domain/market.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:ecoflow/features/recycler/domain/stock.dart';
import 'package:ecoflow/features/tracking/domain/chat.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 1, 9);

Listing listing(
  String id, {
  ListingType type = ListingType.buy,
  String owner = 'acme',
  RecyclableMaterial material = RecyclableMaterial.pet,
  double kg = 500,
  double? price,
  String city = 'Sousse',
  int days = 19,
  String description = '',
}) => Listing(
  id: id,
  type: type,
  ownerUid: owner,
  ownerName: owner.toUpperCase(),
  material: material,
  quantityKg: kg,
  priceDtPerKg: price,
  city: city,
  deadline: now.add(Duration(days: days)),
  description: description,
);

MarketOrder order({OrderStatus status = OrderStatus.confirmed}) => MarketOrder(
  id: 'abcdef123',
  listingId: 'l',
  dealId: 'd',
  sellerUid: 's',
  buyerUid: 'b',
  sellerName: 'GreenPlast',
  buyerName: 'Acme',
  material: RecyclableMaterial.pet,
  form: MaterialForm.flakes,
  quantityKg: 500,
  priceDtPerKg: 1.2,
  deliveryDays: 5,
  number: 'CMD-2026-ABCDEF',
  status: status,
);

void main() {
  test('listing validation (US-094, US-095)', () {
    expect(validateListing(listing('a'), now), isNull, reason: 'buy without price is fine');
    expect(validateListing(listing('a', type: ListingType.sell), now), ListingIssue.price);
    expect(validateListing(listing('a', kg: 0), now), ListingIssue.quantity);
    expect(validateListing(listing('a', days: -1), now), ListingIssue.deadline);
    expect(validateListing(listing('a', city: ' '), now), ListingIssue.city);
    expect(validateListing(listing('a', type: ListingType.sell, price: 1.2), now), isNull);
  });

  test('search and filters: type, material, region, quantity, date, keyword (US-096)', () {
    final all = [
      listing('pet', description: 'PET transparent recyclé'),
      listing('glass', material: RecyclableMaterial.glass, city: 'Monastir', kg: 2000, days: 40),
      listing('sell', type: ListingType.sell, price: 1, city: 'Ksar Hellal'),
      listing('old', days: -2),
    ];
    List<String> ids(ListingFilter f) => [
      for (final l in all.where((l) => f.matches(l, now))) l.id,
    ];
    expect(ids(const ListingFilter()), ['pet', 'glass', 'sell'], reason: 'expired hidden');
    expect(ids(const ListingFilter(type: ListingType.sell)), ['sell']);
    expect(ids(const ListingFilter(material: RecyclableMaterial.glass)), ['glass']);
    expect(ids(const ListingFilter(city: 'monastír')), ['glass'], reason: 'accent-insensitive');
    expect(ids(const ListingFilter(minKg: 1000)), ['glass']);
    expect(ids(ListingFilter(before: now.add(const Duration(days: 20)))), ['pet', 'sell']);
    expect(ids(const ListingFilter(query: 'recycle')), ['pet']);
  });

  test('suggestions from stock and needs (US-102)', () {
    final s = suggest(
      [
        listing('big', kg: 500),
        listing('urgent', kg: 100, days: 3),
        listing('mine', owner: 'me'),
        listing('glass', material: RecyclableMaterial.glass),
        listing('offer', type: ListingType.sell, price: 1, material: RecyclableMaterial.pp),
      ],
      'me',
      stockKg: {RecyclableMaterial.pet: 200},
      wanted: {RecyclableMaterial.pp},
      now: now,
    );
    expect([for (final x in s) x.listing.id], ['urgent', 'offer', 'big']);
    expect(s.firstWhere((x) => x.listing.id == 'big').matchKg, 200);
  });

  test('order workflow by role, totals and number (US-099, US-100, US-104)', () {
    final o = order();
    expect(nextStep(o, 's'), OrderStatus.preparing);
    expect(nextStep(o, 'b'), isNull, reason: 'the buyer waits');
    expect(nextStep(order(status: OrderStatus.delivered), 'b'), OrderStatus.completed);
    expect(nextStep(order(status: OrderStatus.delivered), 's'), isNull);
    expect(canCancel(order(status: OrderStatus.preparing)), isTrue);
    expect(canCancel(order(status: OrderStatus.shipped)), isFalse);
    expect(o.totalHt, 600);
    expect(o.vat, closeTo(114, 1e-9));
    expect(o.totalTtc, closeTo(714, 1e-9));
    expect(orderNumber('abcdef123', now), 'CMD-2026-ABCDEF');
    expect(o.counterpartName('s'), 'Acme');
  });

  test('negotiation: only the recipient answers a pending proposal (US-097)', () {
    const p = MarketMessage(
      id: 'p',
      fromUid: 'b',
      kind: MessageKind.proposal,
      priceDtPerKg: 1,
      quantityKg: 10,
      deliveryDays: 3,
    );
    expect(p.canAnswer('s'), isTrue);
    expect(p.canAnswer('b'), isFalse);
    expect(p.totalDt, 10);
    expect(Deal.idFor('L1', 'u2'), 'L1_u2');
  });

  test('contact details are hidden in negotiations (US-098)', () {
    expect(maskEmails('écris à contact@greenplast.tn stp'), 'écris à •••@••• stp');
    expect(maskPhoneNumbers('appelle le 98 765 432'), 'appelle le •••• ••••');
  });

  group('documents', () {
    const texts = {
      'invoice': 'Facture',
      'seller': 'Vendeur',
      'buyer': 'Acheteur',
      'item': 'Désignation',
      'qty': 'Qté',
      'unit': 'PU',
      'amount': 'Montant',
      'totalHt': 'Total HT',
      'vat': 'TVA',
      'totalTtc': 'Total TTC',
      'payment': 'Paiement',
      'paymentStatus': 'En attente',
      'delivery': 'Livraison',
      'deliveryValue': '5 j',
      'footer': 'EcoFlow',
      'certificate': 'Certificat',
      'intro': 'Certifie',
      'beneficiary': 'Bénéficiaire',
      'recycled': 'recyclé',
      'co2': 'CO2',
      'pickups': 'collectes',
      'lot': 'Lot',
      'material': 'Matière',
      'zones': 'Zones',
      'method': 'Méthode',
    };

    test('invoice PDF (US-104)', () async {
      final bytes = await buildInvoicePdf(order(), texts, material: 'PET', date: '1 oct. 2026');
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('recycling certificate PDF with avoided CO2 (US-105)', () async {
      const lot = StockLot(
        id: 'lot1',
        recyclerUid: 'r',
        material: RecyclableMaterial.aluminium,
        grade: QualityGrade.a,
        initialKg: 100,
        kg: 40,
        zoneIds: ['sousse'],
      );
      final bytes = await buildCertificatePdf(
        [lot],
        texts,
        company: 'GreenPlast',
        number: 'LOT-LOT1',
        date: '1 oct.',
        materialOf: (_) => 'Aluminium',
        beneficiary: 'Acme',
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(co2AvoidedPerKg(RecyclableMaterial.aluminium) * lot.initialKg, 900);
    });
  });
}
