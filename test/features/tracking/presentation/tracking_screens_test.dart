import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/application/matching_service.dart';
import 'package:ecoflow/features/collection/data/collection_repository.dart';
import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/domain/geo.dart';
import 'package:ecoflow/features/collection/domain/time_slot.dart';
import 'package:ecoflow/features/collection/presentation/widgets/location_picker.dart';
import 'package:ecoflow/features/tracking/presentation/screens/chat_screen.dart';
import 'package:ecoflow/features/tracking/presentation/screens/inbox_screen.dart';
import 'package:ecoflow/features/tracking/presentation/widgets/notification_listener.dart';
import 'package:ecoflow/features/tracking/presentation/widgets/tracking_card.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/tracking_fakes.dart';

final now = DateTime(2026, 10, 1, 10, 30);
const home = GeoPoint(35.8256, 10.6084);

CollectionRequest request(CollectionStatus s) => CollectionRequest(
  id: 'c1',
  citizenUid: 'citizen',
  estimateCode: 'CODE2345',
  place: const CollectionPlace(point: home, address: 'Rue 1, Sousse', zoneId: 'sousse'),
  slot: TimeSlot(DateTime(2026, 10, 1), 10, 12),
  estimatedKg: 2,
  estimatedDt: 8,
  status: s,
  collectorUid: 'k',
);

void main() {
  late FakeFirebaseFirestore db;
  late FakeNotifier notifier;

  Future<List<Override>> as(String uid, String role, {Map<String, bool>? prefs}) async {
    resetNotificationListener();
    db = FakeFirebaseFirestore();
    notifier = FakeNotifier();
    await db.doc('users/$uid').set({
      'displayName': uid,
      'role': role,
      'status': 'active',
      'verificationStatus': 'approved',
      'notificationPreferences': ?prefs,
    });
    return [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          initialUser: AuthUser(
            uid: uid,
            phoneNumber: '+21622000000',
            providerIds: const ['phone'],
          ),
        ),
      ),
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      mapTilesEnabledProvider.overrideWithValue(false),
    ];
  }

  Future<void> pumpIt(WidgetTester t, Widget w, List<Override> o) async {
    await pumpRoutedScreen(t, w, overrides: o, size: const Size(420, 2200), notifier: notifier);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
  }

  Future<void> notificationFor(String to, String type) => db.collection('notifications').add({
    'toUid': to,
    'fromUid': 'x',
    'type': type,
    'collectionId': 'c1',
    'address': 'Rue 1, Sousse',
    'read': false,
    'createdAt': now,
  });

  testWidgets('incoming notification → system notification + toast, opens detail (US-065/066)', (
    t,
  ) async {
    final o = await as('k', 'collector');
    await db.collection('notifications').add({
      'toUid': 'k',
      'fromUid': 'x',
      'type': 'assigned',
      'collectionId': 'c1',
      'address': 'old',
      'read': false,
      'createdAt': now.subtract(const Duration(hours: 1)),
    }); // historique
    await pumpIt(
      t,
      Consumer(
        builder: (context, ref, _) {
          listenNotifications(context, ref);
          return const SizedBox();
        },
      ),
      o,
    );
    await t.runAsync(() => notificationFor('k', 'newMission'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
    expect(notifier.shown.single.title, 'Nouvelle mission près de toi 🔔');
    expect(notifier.shown.single.urgent, isTrue, reason: 'sound / max importance');
    expect(notifier.shown.single.payload, '/app/missions/c1');
    expect(find.text('🔔 Nouvelle mission près de toi 🔔'), findsOneWidget);
  });

  testWidgets('status notifications respect the user preference (US-009)', (t) async {
    final o = await as(
      'citizen',
      'citizen',
      prefs: {'collectionStatus': false, 'points': true, 'marketplace': true},
    );
    await pumpIt(
      t,
      Consumer(
        builder: (context, ref, _) {
          listenNotifications(context, ref);
          return const SizedBox();
        },
      ),
      o,
    );
    await t.runAsync(() => notificationFor('citizen', 'onTheWay'));
    await t.runAsync(() => notificationFor('citizen', 'message'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
    expect(notifier.shown.map((n) => n.title), ['Nouveau message 💬']);
  });

  testWidgets('tracking card shows collector ETA, then "on site" (US-063/064)', (t) async {
    final o = await as('citizen', 'citizen');
    await db.doc('liveLocations/c1').set({
      'collectorUid': 'k',
      'point': {'lat': 35.8436, 'lng': 10.6084},
      'speedKmh': 30.0,
      'at': now,
    });
    await pumpIt(t, TrackingCard(request: request(CollectionStatus.onTheWay)), o);
    expect(find.text('Arrivée estimée'), findsOneWidget);
    expect(find.textContaining('dans 5 min'), findsOneWidget, reason: '2.34 km road at 30 km/h');
    await pumpIt(t, TrackingCard(request: request(CollectionStatus.arrived)), o);
    expect(find.text('📍 Le collecteur est sur place'), findsOneWidget);
  });

  testWidgets('chat screen sends masked message; call explains limitation (US-067)', (t) async {
    final o = await as('citizen', 'citizen');
    await db.doc('collections/c1').set({
      'citizenUid': 'citizen',
      'collectorUid': 'k',
      'status': 'onTheWay',
      'place': {'point': home.toMap(), 'address': 'Rue 1, Sousse', 'zoneId': 'sousse'},
      'slotId': '2026-10-01_10',
      'estimateCode': 'CODE2345',
    });
    await pumpIt(t, const ChatScreen(collectionId: 'c1'), o);
    expect(find.textContaining('Numéros de téléphone masqués'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'Appelle le 22 123 456');
    await t.tap(find.text('Envoyer'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await settle(t);
    expect(find.text('Appelle le •••• ••••'), findsOneWidget);
    await t.tap(find.text('📞 Appel masqué'));
    await settle(t);
    expect(find.textContaining('fournisseur de téléphonie'), findsOneWidget);
  });

  testWidgets('inbox lists notifications and marks all read', (t) async {
    final o = await as('citizen', 'citizen');
    await notificationFor('citizen', 'arrived');
    await notificationFor('citizen', 'onTheWay');
    await pumpIt(t, const InboxScreen(), o);
    expect(find.text('2 non lues'), findsOneWidget);
    expect(find.text('Le collecteur est arrivé 📍'), findsOneWidget);
    await t.tap(find.text('Tout marquer comme lu'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
    await settle(t);
    expect(find.text('Tout est lu'), findsOneWidget);
  });

  test('matching notifies the proposed collector (US-066)', () async {
    final fdb = FakeFirebaseFirestore();
    await fdb.doc('collectorPresence/k').set({
      'online': true,
      'point': {'lat': 35.83, 'lng': 10.61},
      'capacityKg': 100.0,
    });
    await fdb.doc('estimates/CODE2345').set({'citizenUid': 'citizen', 'status': 'estimated'});
    final c = await testContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            initialUser: const AuthUser(
              uid: 'citizen',
              phoneNumber: '+21622000000',
              providerIds: ['phone'],
            ),
          ),
        ),
        firestoreProvider.overrideWithValue(fdb),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    final id = await FirestoreCollectionRepository(fdb).create(request(CollectionStatus.searching));
    final created = (await FirestoreCollectionRepository(fdb).fetch(id))!;
    final probe = c.read(Provider<Ref>((ref) => ref));
    await runMatching(probe, created);
    final n = (await fdb.collection('notifications').get()).docs.single.data();
    expect(n['type'], 'newMission');
    expect(n['toUid'], 'k');
  });
}
