import 'dart:io';

import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/recycler/application/recycler_providers.dart';
import 'package:ecoflow/features/recycler/presentation/screens/dashboard_screen.dart';
import 'package:ecoflow/features/recycler/presentation/screens/lot_detail_screen.dart';
import 'package:ecoflow/features/recycler/presentation/screens/purchasing_screen.dart';
import 'package:ecoflow/features/recycler/presentation/screens/stock_screen.dart';
import 'package:ecoflow/features/vision_admin/application/vision_admin_controllers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  final shared = <String>[];
  final now = DateTime(2026, 10, 1, 12);

  Future<void> lot(
    String id,
    String material,
    double kg, {
    String collector = 'k1',
    String zone = 'sousse',
    String form = 'raw',
    List<String> inputs = const [],
    List<Map<String, Object>> missions = const [],
  }) => db.doc('lots/$id').set({
    'recyclerUid': 'rec',
    'material': material,
    'grade': 'a',
    'form': form,
    'source': inputs.isEmpty ? 'reception' : 'production',
    'initialKg': kg,
    'kg': kg,
    'depositId': 'dep1',
    'collectorUid': collector,
    'collectorName': collector.toUpperCase(),
    'zoneIds': [zone],
    'missions': missions,
    'inputLotIds': inputs,
    'marketplace': false,
    'receivedAt': now.subtract(const Duration(days: 2)),
  });

  Future<List<Override>> recycler() async {
    db = FakeFirebaseFirestore();
    shared.clear();
    await db.doc('users/rec').set({
      'displayName': 'GreenPlast',
      'role': 'recycler',
      'status': 'active',
    });
    await db.doc('companies/rec').set({
      'legalName': 'GreenPlast SARL',
      'status': 'approved',
      'ownerUid': 'rec',
    });
    return [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          initialUser: const AuthUser(uid: 'rec', email: 'r@x.tn', providerIds: ['password']),
        ),
      ),
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
      fileSharerProvider.overrideWithValue((path) async => shared.add(path)),
      exportDirectoryProvider.overrideWithValue(() => Directory.systemTemp.createTemp('ecoflow')),
    ];
  }

  Future<void> pumpIt(WidgetTester t, Widget w, List<Override> o) async {
    await pumpRoutedScreen(t, w, overrides: o, size: const Size(420, 2600));
    await settle(t);
  }

  testWidgets('dashboard: quantities by material, filters, Excel export (US-079, 082, 083)', (
    t,
  ) async {
    final o = await recycler();
    await lot('p1', 'pet', 850);
    await lot('h1', 'hdpe', 320);
    await lot('pp1', 'pp', 180, collector: 'k2', zone: 'monastir');
    await pumpIt(t, const DashboardScreen(), o);
    expect(find.textContaining(RegExp(r'^1\s350,00$')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp(r'^🧴 PET : 850,00 kg · 63 %')), findsOneWidget);
    expect(find.text('K2'), findsWidgets);
    await t.tap(find.text('Toutes les zones'));
    await settle(t);
    await t.tap(find.text('Monastir').last);
    await settle(t);
    expect(find.text('180,00'), findsWidgets);
    await t.ensureVisible(find.text('Exporter en Excel'));
    await t.tap(find.text('Exporter en Excel'));
    for (var i = 0; i < 40 && shared.isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await t.pump();
    }
    expect(shared.single, endsWith('ecoflow_approvisionnements_2026-10-01.xlsx'));
    expect(File(shared.single).lengthSync(), greaterThan(500));
  });

  testWidgets('dashboard PDF export embeds the app font', (t) async {
    final o = await recycler();
    await lot('p1', 'pet', 10);
    await pumpIt(t, const DashboardScreen(), o);
    final font = await t.runAsync(() => rootBundle.load('assets/fonts/BricolageGrotesque.ttf'));
    expect(font!.lengthInBytes, greaterThan(10000));
    await t.ensureVisible(find.text('Exporter en PDF'));
    await t.tap(find.text('Exporter en PDF'));
    // Chargement de la police puis rendu : alterner temps réel et pompage.
    for (var i = 0; i < 40 && shared.isEmpty; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await t.pump();
    }
    expect(shared.single, endsWith('.pdf'));
    expect(String.fromCharCodes(File(shared.single).readAsBytesSync().take(5)), '%PDF-');
  });

  testWidgets('stock: totals by grade and production declaration (US-081, US-087)', (t) async {
    final o = await recycler();
    await lot('p1', 'pet', 40);
    await lot('g1', 'glass', 12);
    await pumpIt(t, const StockScreen(), o);
    expect(find.bySemanticsLabel(RegExp('PET : 40,00 kg · A 40,00')), findsOneWidget);
    await t.tap(find.text('Déclarer une production'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'Matière consommée (kg)'), '30');
    await t.enterText(find.widgetWithText(TextFormField, 'Production obtenue (kg)'), '27');
    await settle(t);
    expect(find.text('Rendement : 90 %'), findsOneWidget);
    await t.ensureVisible(find.text('Granulés'));
    await t.tap(find.text('Granulés'));
    await settle(t);
    await t.ensureVisible(find.text('Enregistrer la production'));
    await t.tap(find.text('Enregistrer la production'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await settle(t);
    final lots = {for (final d in (await db.collection('lots').get()).docs) d.id: d.data()};
    expect(lots['p1']!['kg'], 10);
    final out = lots.values.firstWhere((l) => l['source'] == 'production');
    expect((out['form'], out['kg']), ('granules', 27.0));
    expect(out['inputLotIds'], ['p1']);
  });

  testWidgets('lot traceability back to the pickups (US-084)', (t) async {
    final o = await recycler();
    await lot(
      'p1',
      'pet',
      8,
      missions: [
        {'id': 'abcdef123', 'zoneId': 'sousse', 'day': DateTime(2026, 9, 29), 'kg': 5.0},
        {'id': 'xyz', 'zoneId': 'sousse', 'day': DateTime(2026, 9, 30), 'kg': 3.0},
      ],
    );
    await lot('f1', 'pet', 7, form: 'flakes', inputs: ['p1']);
    await pumpIt(t, const LotDetailScreen(id: 'p1'), o);
    expect(find.text('LOT-P1'), findsOneWidget);
    expect(find.text('K1'), findsOneWidget);
    expect(find.text('Collecte abcdef'), findsOneWidget);
    expect(find.textContaining('5,00 kg'), findsOneWidget);
    await pumpIt(t, const LotDetailScreen(id: 'f1'), o);
    expect(find.text('LOT-P1 · K1'), findsOneWidget);
    await t.tap(find.text('LOT-P1 · K1'));
    await settle(t);
    expect(find.text('route:/app/stock/p1'), findsOneWidget);
  });

  testWidgets('purchase terms per material (US-085)', (t) async {
    final o = await recycler();
    await pumpIt(t, const PurchasingScreen(), o);
    await t.tap(find.text('🧴 PET'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'Prix (DT/kg)').first, '0,45');
    await t.enterText(find.widgetWithText(TextFormField, 'Capacité (kg/mois)').first, '5000');
    await t.ensureVisible(find.text('Enregistrer'));
    await t.tap(find.text('Enregistrer'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await settle(t);
    final p = (await db.doc('companies/rec').get()).data()!['purchasing'] as Map;
    expect(p['pet'], {'accepting': true, 'priceDtPerKg': .45, 'capacityKgMonth': 5000.0});
    expect(p['glass']['accepting'], isFalse);
  });
}
