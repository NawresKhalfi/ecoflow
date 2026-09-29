import 'package:ecoflow/app.dart';
import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/core/localization/language_controller.dart';
import 'package:ecoflow/core/storage/local_preferences.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_repository.dart';
import 'helpers/test_app.dart';

/// Parcours complet sur l'application réelle (routeur + garde), avec
/// Firebase remplacé par des fakes.
void main() {
  late FakeAuthRepository auth;
  late FakeFirebaseFirestore db;

  Future<void> pumpApp(WidgetTester t) async {
    t.view.physicalSize = const Size(420, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          localPreferencesProvider.overrideWithValue(await memoryPrefs()),
          deviceLocalesProvider.overrideWithValue(const [Locale('fr')]),
          authRepositoryProvider.overrideWithValue(auth),
          firestoreProvider.overrideWithValue(db),
        ],
        retry: (_, _) => null,
        child: const EcoFlowApp(),
      ),
    );
    await settle(t);
  }

  Future<void> tap(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text).last);
    await t.tap(find.text(text).last);
    await settle(t);
  }

  setUp(() {
    auth = FakeAuthRepository();
    db = FakeFirebaseFirestore();
  });

  testWidgets('email sign-up → verification gate → role space', (t) async {
    await pumpApp(t);
    expect(find.text('Choisis ton espace pour commencer'), findsOneWidget);

    await tap(t, 'Citoyen');
    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'Amine Ben Ali');
    await t.enterText(fields.at(1), 'amine@eco.tn');
    await t.enterText(fields.at(2), 'recycle26');
    await t.enterText(fields.at(3), 'recycle26');
    await t.tap(find.byType(Checkbox));
    await settle(t);
    await tap(t, 'Créer mon compte');
    expect(find.text('Vérifie ta boîte mail 📬'), findsOneWidget);

    await tap(t, 'J’ai confirmé mon e-mail');
    expect(find.text('Vérifie ta boîte mail 📬'), findsOneWidget, reason: 'not verified yet');

    auth.verifiedEmails.add('amine@eco.tn');
    await auth.signInWithEmail('amine@eco.tn', 'recycle26');
    await settle(t);
    expect(find.text('Bonjour Amine 👋'), findsOneWidget);
    expect(find.text('Adresses'), findsOneWidget);
  });

  testWidgets('language switch is applied instantly with RTL for Arabic', (t) async {
    await pumpApp(t);
    await t.tap(find.byIcon(Icons.translate));
    await settle(t);
    await tap(t, 'العربية');
    expect(Directionality.of(t.element(find.text('اللغة').first)), TextDirection.rtl);
    await tap(t, 'English');
    expect(find.text('Language'), findsWidgets);
    expect(Directionality.of(t.element(find.text('Language').first)), TextDirection.ltr);
  });

  testWidgets('phone sign-in without profile goes to profile completion', (t) async {
    await pumpApp(t);
    await tap(t, 'Continuer avec mon téléphone');
    await t.enterText(find.byType(TextFormField), '22123456');
    await tap(t, 'Recevoir le code');
    await t.enterText(find.byType(TextFormField), '123456');
    await tap(t, 'Vérifier');
    expect(find.text('Finalise ton profil'), findsOneWidget);

    await t.enterText(find.byType(TextFormField), 'Karim B');
    await tap(t, 'Collecteur');
    await t.tap(find.byType(Checkbox));
    await settle(t);
    await tap(t, 'Accéder à mon espace');
    expect(find.text('Bonjour Karim 👋'), findsOneWidget);
    expect(find.text('Dossier'), findsOneWidget);
  });
}
