import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/collection/presentation/widgets/location_picker.dart';
import 'package:ecoflow/features/forecast/domain/forecast_model.dart';
import 'package:ecoflow/features/forecast/domain/zone_forecast.dart';
import 'package:ecoflow/features/forecast/presentation/screens/forecast_admin_screen.dart';
import 'package:ecoflow/features/forecast/presentation/screens/forecast_screen.dart';
import 'package:ecoflow/features/forecast/presentation/screens/heatmap_screen.dart';
import 'package:ecoflow/features/recycler/presentation/screens/dashboard_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';
import '../application/forecast_flow_test.dart' show now, seedHistory;

GroupForecast g(double n7) => GroupForecast(
  next7: n7,
  next30: n7 * 4.3,
  low7: n7 * .8,
  high7: n7 * 1.2,
  last7: n7 * .9,
  last30: n7 * 4,
  daily: List.filled(14, n7 / 7),
);

void main() {
  late FakeFirebaseFirestore db;

  Future<List<Override>> as(String uid, String role) async {
    db = FakeFirebaseFirestore();
    await db.doc('users/$uid').set({'displayName': uid, 'role': role, 'status': 'active'});
    await db.doc('companies/$uid').set({'legalName': 'GreenPlast', 'status': 'approved'});
    return [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          initialUser: AuthUser(
            uid: uid,
            phoneNumber: '+21622000009',
            providerIds: const ['phone'],
          ),
        ),
      ),
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      mapTilesEnabledProvider.overrideWithValue(false),
    ];
  }

  Future<void> publish(String zone, String name, double plastic) => db.doc('forecasts/$zone').set({
    ...ZoneForecast(
      zoneId: zone,
      zoneName: name,
      method: ForecastMethod.holtWinters,
      samples: 90,
      mape: .12,
      wape: .1,
      groups: {MaterialGroup.plastic: g(plastic), MaterialGroup.glass: g(10)},
    ).toMap(),
    'trainedAt': now,
  });

  Future<void> pumpIt(WidgetTester t, Widget w, List<Override> o) async {
    await pumpRoutedScreen(t, w, overrides: o, size: const Size(420, 2600));
    await settle(t);
  }

  testWidgets('recycler: 7 / 30-day forecast per zone (US-088)', (t) async {
    final o = await as('rec', 'recycler');
    await publish('sousse', 'Sousse', 700);
    await publish('monastir', 'Monastir', 300);
    await pumpIt(t, const ForecastScreen(), o);
    expect(
      find.bySemanticsLabel(RegExp(r'Plastique attendu : 1\s000,00 kg sur 7 jours')),
      findsOneWidget,
    );
    expect(find.textContaining('7 j : 700,00 kg'), findsOneWidget);
    expect(find.textContaining('fiable'), findsOneWidget);
    await t.tap(find.text('Monastir'));
    await settle(t);
    expect(find.textContaining('7 j : 300,00 kg'), findsOneWidget);
  });

  testWidgets('recycler dashboard shows forecasts for the filtered zone (US-089)', (t) async {
    final o = await as('rec', 'recycler');
    await publish('sousse', 'Sousse', 700);
    await publish('monastir', 'Monastir', 300);
    await pumpIt(t, const DashboardScreen(), o);
    expect(find.bySemanticsLabel(RegExp(r'Plastique attendu : 1\s000,00 kg')), findsOneWidget);
    await t.tap(find.bySemanticsLabel(RegExp('Plastique attendu')));
    await settle(t);
    expect(find.text('route:/app/forecast'), findsOneWidget);
  });

  testWidgets('admin: retrain, accuracy and alerts (US-091 to US-093)', (t) async {
    final o = await as('admin', 'admin');
    await seedHistory(db);
    await db.doc('collectorPresence/k1').set({'capacityKg': 5.0});
    await pumpIt(t, const ForecastAdminScreen(), o);
    expect(find.text('Jamais entraîné'), findsOneWidget);
    await t.tap(find.text('Réentraîner maintenant'));
    for (
      var i = 0;
      i < 20 && (await t.runAsync(() => db.collection('forecastRuns').get()))!.docs.isEmpty;
      i++
    ) {
      await t.pump(const Duration(milliseconds: 100));
    }
    await settle(t);
    expect(find.textContaining('Dernier entraînement'), findsOneWidget);
    expect(find.textContaining('surcharge prévue'), findsOneWidget);
    expect(find.textContaining('MAPE'), findsWidgets);
  });

  testWidgets('admin heatmap lists zones by expected volume (US-090)', (t) async {
    final o = await as('admin', 'admin');
    await seedHistory(db);
    await publish('sousse', 'Sousse', 700);
    await pumpIt(t, const HeatmapScreen(), o);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await settle(t);
    expect(find.textContaining('30 j : 3'), findsOneWidget);
    expect(find.textContaining('Volume collecté par secteur'), findsOneWidget);
  });
}
