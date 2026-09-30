import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/domain/collection_request.dart';
import 'package:ecoflow/features/collection/presentation/widgets/location_picker.dart';
import 'package:ecoflow/features/missions/presentation/screens/missions_screen.dart';
import 'package:ecoflow/features/routing/presentation/screens/optimization_screen.dart';
import 'package:ecoflow/features/routing/presentation/screens/tour_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';
import '../application/routing_flow_test.dart' show seed, now;

void main() {
  late FakeFirebaseFirestore db;

  Future<List<Override>> as(String role) async {
    db = FakeFirebaseFirestore();
    await db.doc('users/k').set({
      'displayName': 'K',
      'role': role,
      'status': 'active',
      'verificationStatus': 'approved',
    });
    await db.doc('collectorPresence/k').set({
      'online': true,
      'point': {'lat': 35.8256, 'lng': 10.6084},
    });
    return [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          initialUser: const AuthUser(
            uid: 'k',
            phoneNumber: '+21622000000',
            providerIds: ['phone'],
          ),
        ),
      ),
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      mapTilesEnabledProvider.overrideWithValue(false),
    ];
  }

  Future<void> pumpIt(WidgetTester t, Widget w, List<Override> o) async {
    await pumpRoutedScreen(t, w, overrides: o, size: const Size(420, 3200));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await settle(t);
  }

  testWidgets('tour screen: ordered stops, savings, detour suggestion', (t) async {
    final o = await as('collector');
    await seed(db, 'Rue far', 35.8656, 10.6084, collector: 'k');
    await seed(db, 'Rue near', 35.8356, 10.6084, collector: 'k');
    await seed(db, 'Rue onway', 35.8506, 10.6090, status: CollectionStatus.searching);
    await pumpIt(t, const TourScreen(), o);
    expect(find.text('Rue near'), findsOneWidget);
    expect(find.text('Rue far'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('Économies'), findsOneWidget);
    expect(find.text('Rue onway'), findsOneWidget);
    expect(find.textContaining('de détour'), findsOneWidget);
    expect(find.textContaining('Calculée en'), findsOneWidget);
  });

  testWidgets('missions screen shows tour entry and grouped suggestion', (t) async {
    final o = await as('collector');
    await seed(db, 'Mine', 35.8356, 10.6084, collector: 'k');
    await seed(db, 'x1', 35.8300, 10.6100, status: CollectionStatus.searching);
    await seed(db, 'x2', 35.8320, 10.6110, status: CollectionStatus.searching);
    await pumpIt(t, const MissionsScreen(), o);
    expect(find.text('Voir ma tournée optimisée'), findsOneWidget);
    expect(find.text('🧠 Tournée groupée suggérée'), findsOneWidget);
    expect(find.text('Accepter le groupe'), findsOneWidget);
  });

  testWidgets('optimization screen: draft, simulation, publish with history', (t) async {
    final o = await as('admin');
    await pumpIt(t, const OptimizationScreen(), o);
    expect(find.text('Paramètres publiés'), findsOneWidget);
    expect(find.textContaining('Optimisé'), findsOneWidget);
    await t.drag(find.byType(Slider).at(2), const Offset(60, 0));
    await settle(t);
    expect(find.text('Brouillon'), findsOneWidget);
    await t.ensureVisible(find.text('Publier les paramètres'));
    await t.tap(find.text('Publier les paramètres'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await settle(t);
    expect((await db.collection('config/optimization/history').get()).docs, hasLength(1));
    expect(find.text('Historique'), findsOneWidget);
  });
}
