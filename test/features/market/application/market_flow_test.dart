import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/market/application/market_providers.dart';
import 'package:ecoflow/features/market/domain/market.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:ecoflow/features/recycler/domain/stock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

final now = DateTime(2026, 10, 1, 9);

void main() {
  late FakeFirebaseFirestore db;

  Future<ProviderContainer> as(String uid) async {
    final c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: AuthUser(
              uid: uid,
              phoneNumber: '+2162200000${uid.length}',
              providerIds: const ['phone'],
            ),
          ),
        ),
        firestoreProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    c
      ..listen(currentUidProvider, (_, _) {})
      ..listen(marketControllerProvider, (_, _) {});
    await pumpEventQueue();
    return c;
  }

  MarketController ctrl(ProviderContainer c) => c.read(marketControllerProvider.notifier);

  setUp(() async {
    db = FakeFirebaseFirestore();
    for (final (uid, name) in [('green', 'GreenPlast'), ('acme', 'Acme Plastiques')]) {
      await db.doc('users/$uid').set({'displayName': name, 'role': 'recycler', 'status': 'active'});
      await db.doc('companies/$uid').set({
        'legalName': name,
        'status': 'approved',
        'city': 'Sousse',
      });
    }
    // Deux lots de paillettes PET en stock chez GreenPlast.
    for (final (id, kg, days) in [('old', 300.0, 9), ('new', 400.0, 1)]) {
      await db.doc('lots/$id').set({
        ...StockLot(
          id: id,
          recyclerUid: 'green',
          material: RecyclableMaterial.pet,
          grade: QualityGrade.a,
          form: MaterialForm.flakes,
          initialKg: kg,
          kg: kg,
          zoneIds: const ['sousse'],
        ).toMap(),
        'missions': [
          {'id': 'c$id', 'zoneId': 'sousse', 'day': now, 'kg': kg},
        ],
        'receivedAt': now.subtract(Duration(days: days)),
      });
    }
  });

  test('from a stock listing to a delivered, paid and rated order', () async {
    final green = await as('green');
    expect(
      await ctrl(green).saveListing(
        Listing(
          id: '',
          type: ListingType.sell,
          ownerUid: 'green',
          ownerName: 'GreenPlast',
          material: RecyclableMaterial.pet,
          form: MaterialForm.flakes,
          quantityKg: 500,
          priceDtPerKg: 1.2,
          city: 'Sousse',
          deadline: now.add(const Duration(days: 30)),
          lotIds: const ['old', 'new'],
        ),
      ),
      isTrue,
    );
    final listing = (await green.read(marketRepositoryProvider).watchMine('green').first).single;

    // L'acheteur négocie et propose.
    final acme = await as('acme');
    await ctrl(acme).openDeal(listing, 'Acme Plastiques', '500 kg PET');
    final dealId = ctrl(acme).lastId!;
    expect(dealId, '${listing.id}_acme');
    final deal = (await acme.read(marketRepositoryProvider).watchDeal(dealId).first)!;
    await ctrl(acme).sendText(deal, 'Bonjour, appelez-moi au 98 765 432');
    expect(await ctrl(acme).propose(deal, price: 1.1, quantity: 500, days: 5), isTrue);
    final msgs = await acme.read(marketRepositoryProvider).watchMessages(dealId).first;
    expect(msgs.first.text, contains('•••• ••••'));
    final proposal = msgs.firstWhere((m) => m.kind == MessageKind.proposal);
    var notes = (await db.collection('notifications').get()).docs.map((d) => d.data()).toList();
    expect(notes.map((n) => (n['toUid'], n['type'])), contains(('green', 'marketProposal')));

    // Le vendeur accepte : commande aux conditions de la proposition.
    expect(await ctrl(green).answer(deal, listing, proposal, accept: true), isTrue);
    final orderId = ctrl(green).lastId!;
    expect(orderId, proposal.id);
    var o = (await green.read(marketRepositoryProvider).watchOrder(orderId).first)!;
    expect((o.sellerUid, o.buyerUid, o.priceDtPerKg, o.quantityKg), ('green', 'acme', 1.1, 500.0));
    expect(o.lotIds, ['old', 'new']);
    expect((await db.doc('listings/${listing.id}').get()).data()!['status'], 'closed');

    // Préparation, expédition : 500 kg sortis du stock, les plus anciens d'abord.
    await ctrl(green).advance(o);
    o = (await green.read(marketRepositoryProvider).watchOrder(orderId).first)!;
    expect(await ctrl(acme).advance(o), isFalse, reason: 'only the seller ships');
    await ctrl(green).advance(o);
    expect((await db.doc('lots/old').get()).data()!['kg'], 0);
    expect((await db.doc('lots/new').get()).data()!['kg'], 200);
    final sales = (await db.collection('stockMoves').get()).docs.where(
      (d) => d.data()['reason'] == 'sale',
    );
    expect(sales.length, 2);
    o = (await green.read(marketRepositoryProvider).watchOrder(orderId).first)!;
    expect((o.status, o.originPickups), (OrderStatus.shipped, 2));
    expect(o.originZones, ['sousse']);

    // Livraison, paiement, réception, notes.
    await ctrl(green).advance(o);
    o = (await acme.read(marketRepositoryProvider).watchOrder(orderId).first)!;
    await ctrl(acme).payment(o);
    o = (await green.read(marketRepositoryProvider).watchOrder(orderId).first)!;
    await ctrl(green).payment(o);
    await ctrl(acme).advance(o);
    o = (await acme.read(marketRepositoryProvider).watchOrder(orderId).first)!;
    expect((o.status, o.payment), (OrderStatus.completed, PaymentStatus.received));
    await ctrl(acme).rate(o, 5);
    await ctrl(green).rate(o, 4);
    expect((await db.doc('companyStats/green').get()).data(), {'ratingCount': 1, 'ratingAvg': 5.0});
    expect((await db.doc('companyStats/acme').get()).data()!['ratingAvg'], 4.0);
    notes = (await db.collection('notifications').get()).docs.map((d) => d.data()).toList();
    expect(
      notes.where((n) => n['toUid'] == 'acme' && n['type'] == 'orderUpdate').length,
      greaterThanOrEqualTo(3),
    );
  });

  test('purchase request: the responder is the seller; declined proposals stay open', () async {
    final acme = await as('acme');
    await ctrl(acme).saveListing(
      Listing(
        id: '',
        type: ListingType.buy,
        ownerUid: 'acme',
        ownerName: 'Acme',
        material: RecyclableMaterial.pet,
        quantityKg: 1000,
        city: 'Sousse',
        deadline: now.add(const Duration(days: 19)),
      ),
    );
    final listing = (await acme.read(marketRepositoryProvider).watchMine('acme').first).single;
    final green = await as('green');
    await ctrl(green).openDeal(listing, 'GreenPlast', '1000 kg PET');
    final deal = (await green.read(marketRepositoryProvider).watchDeal(ctrl(green).lastId!).first)!;
    await ctrl(green).propose(deal, price: 1.3, quantity: 400, days: 3);
    var p = (await green.read(marketRepositoryProvider).watchMessages(deal.id).first).single;
    await ctrl(acme).answer(deal, listing, p, accept: false);
    p = (await green.read(marketRepositoryProvider).watchMessages(deal.id).first).single;
    expect(p.status, ProposalStatus.declined);
    await ctrl(green).propose(deal, price: 1.25, quantity: 400, days: 3);
    p = (await green.read(marketRepositoryProvider).watchMessages(deal.id).first).firstWhere(
      (m) => m.status == ProposalStatus.pending,
    );
    await ctrl(acme).answer(deal, listing, p, accept: true);
    final o = (await db.doc('orders/${p.id}').get()).data()!;
    expect((o['sellerUid'], o['buyerUid']), ('green', 'acme'));
    expect(o['lotIds'], isEmpty);
    expect(
      (await db.doc('listings/${listing.id}').get()).data()!['status'],
      'open',
      reason: '400 of 1000 kg',
    );
  });

  test('suggestions and reports (US-102, US-103)', () async {
    final acme = await as('acme');
    await ctrl(acme).saveListing(
      Listing(
        id: '',
        type: ListingType.buy,
        ownerUid: 'acme',
        ownerName: 'Acme',
        material: RecyclableMaterial.pet,
        quantityKg: 600,
        city: 'Sousse',
        deadline: now.add(const Duration(days: 5)),
      ),
    );
    final green = await as('green');
    green
      ..listen(suggestionsProvider, (_, _) {})
      ..listen(openListingsProvider, (_, _) {});
    await pumpEventQueue();
    final s = green.read(suggestionsProvider);
    expect(s.single.matchKg, 600, reason: '700 kg in stock');
    await ctrl(green).report(s.single.listing, ReportReason.spam, 'x');
    expect((await db.collection('listingReports').get()).docs.single.data()['reason'], 'spam');
  });
}
