import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/market/domain/market.dart';
import 'package:ecoflow/features/market/presentation/screens/deal_screen.dart';
import 'package:ecoflow/features/market/presentation/screens/listing_detail_screen.dart';
import 'package:ecoflow/features/market/presentation/screens/market_screen.dart';
import 'package:ecoflow/features/market/presentation/screens/moderation_screen.dart';
import 'package:ecoflow/features/market/presentation/screens/order_detail_screen.dart';
import 'package:ecoflow/features/profile/domain/company_profile.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

final now = DateTime(2026, 10, 1, 9);

void main() {
  late FakeFirebaseFirestore db;

  Future<List<Override>> as(String uid, {String role = 'recycler'}) async {
    await db.doc('users/$uid').set({'displayName': uid, 'role': role, 'status': 'active'});
    await db.doc('companies/$uid').set({
      'legalName': uid.toUpperCase(),
      'status': 'approved',
      'city': 'Sousse',
    });
    return [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          initialUser: AuthUser(
            uid: uid,
            phoneNumber: '+21622000077',
            providerIds: const ['phone'],
          ),
        ),
      ),
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
    ];
  }

  Future<void> listing(
    String id, {
    required String owner,
    ListingType type = ListingType.buy,
    RecyclableMaterial m = RecyclableMaterial.pet,
    String city = 'Sousse',
  }) => db.doc('listings/$id').set({
    ...Listing(
      id: id,
      type: type,
      ownerUid: owner,
      ownerName: owner.toUpperCase(),
      material: m,
      quantityKg: 500,
      priceDtPerKg: type == ListingType.sell ? 1.2 : null,
      city: city,
      deadline: now.add(const Duration(days: 19)),
    ).toMap(),
    'createdAt': now,
  });

  Future<void> pumpIt(WidgetTester t, Widget w, List<Override> o) async {
    await pumpRoutedScreen(t, w, overrides: o, size: const Size(420, 2600));
    await settle(t);
  }

  setUp(() => db = FakeFirebaseFirestore());

  testWidgets('browse and filter listings (US-096)', (t) async {
    final o = await as('green');
    await listing('a', owner: 'acme');
    await listing('b', owner: 'acme', m: RecyclableMaterial.glass, city: 'Monastir');
    await listing('mine', owner: 'green');
    await pumpIt(t, const MarketScreen(), o);
    expect(find.text('2 annonces'), findsOneWidget, reason: 'own listings hidden');
    await t.enterText(find.widgetWithText(TextFormField, 'Ville'), 'monastir');
    await settle(t);
    expect(find.text('1 annonce'), findsOneWidget);
    expect(find.textContaining('Verre'), findsWidgets);
  });

  testWidgets('respond to a purchase request opens the negotiation (US-097)', (t) async {
    final o = await as('green');
    await listing('a', owner: 'acme');
    await pumpIt(t, const ListingDetailScreen(id: 'a'), o);
    await t.tap(find.text('Répondre avec une offre'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await settle(t);
    expect(find.text('route:/app/market/deal/a_green'), findsOneWidget);
    expect((await db.doc('deals/a_green').get()).data()!['members'], ['acme', 'green']);
  });

  testWidgets('accepting a proposal creates the order (US-099)', (t) async {
    final o = await as('acme');
    await listing('a', owner: 'acme');
    await db.doc('deals/a_green').set({
      'listingId': 'a',
      'ownerUid': 'acme',
      'counterpartUid': 'green',
      'members': ['acme', 'green'],
      'ownerName': 'ACME',
      'counterpartName': 'GREEN',
      'listingTitle': '500 kg PET',
    });
    await db.doc('deals/a_green/messages/p1').set({
      'fromUid': 'green',
      'kind': 'proposal',
      'text': '',
      'priceDtPerKg': 1.25,
      'quantityKg': 500.0,
      'deliveryDays': 4,
      'status': 'pending',
      'at': now,
    });
    await pumpIt(t, const DealScreen(id: 'a_green'), o);
    expect(find.textContaining('625,000'), findsOneWidget, reason: 'total HT');
    await t.tap(find.text('Accepter'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await settle(t);
    expect(find.text('route:/app/market/orders/p1'), findsOneWidget);
    final order = (await db.doc('orders/p1').get()).data()!;
    expect(
      (order['sellerUid'], order['buyerUid'], order['status']),
      ('green', 'acme', 'confirmed'),
    );
  });

  testWidgets('order detail: seller advances, totals with VAT (US-100, US-104)', (t) async {
    final o = await as('green');
    await db.doc('orders/p1').set({
      'listingId': 'a',
      'dealId': 'a_green',
      'sellerUid': 'green',
      'buyerUid': 'acme',
      'sellerName': 'GREEN',
      'buyerName': 'ACME',
      'parties': ['acme', 'green'],
      'material': 'pet',
      'form': 'flakes',
      'quantityKg': 500.0,
      'priceDtPerKg': 1.2,
      'deliveryDays': 4,
      'number': 'CMD-2026-P1',
      'status': 'confirmed',
      'payment': 'pending',
      'lotIds': <String>[],
      'createdAt': now,
    });
    await pumpIt(t, const OrderDetailScreen(id: 'p1'), o);
    expect(find.textContaining('714,000'), findsOneWidget, reason: '600 HT + 19 % TVA');
    await t.tap(find.text('Commencer la préparation'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await settle(t);
    expect((await db.doc('orders/p1').get()).data()!['status'], 'preparing');
    expect(find.text('Marquer comme expédiée'), findsOneWidget);
  });

  testWidgets('admin suspends a reported listing (US-103)', (t) async {
    final o = await as('admin', role: 'admin');
    await listing('a', owner: 'acme');
    await db.collection('listingReports').add({
      'listingId': 'a',
      'reporterUid': 'green',
      'reason': 'spam',
      'text': 'Annonce en double',
      'resolved': false,
      'at': now,
    });
    await pumpIt(t, const ModerationScreen(), o);
    expect(find.textContaining('1 signalement'), findsOneWidget);
    await t.tap(find.text('Suspendre').first);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await settle(t);
    expect((await db.doc('listings/a').get()).data()!['status'], 'suspended');
    await t.tap(find.text('Traité'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await settle(t);
    expect(find.textContaining('Aucun signalement'), findsWidgets);
  });
}
