import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:ecoflow/features/auth/presentation/screens/phone_screen.dart';
import 'package:ecoflow/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:ecoflow/features/auth/presentation/screens/sign_up_screen.dart';
import 'package:ecoflow/features/auth/presentation/screens/welcome_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeFirebaseFirestore db;

  setUp(() {
    auth = FakeAuthRepository();
    db = FakeFirebaseFirestore();
  });

  List<Override> overrides() => [
    authRepositoryProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(db),
  ];

  Future<void> tapText(WidgetTester t, String text) async {
    await t.ensureVisible(find.text(text).last);
    await t.tap(find.text(text).last);
    await settle(t);
  }

  testWidgets('welcome offers the 3 self-selectable spaces, never admin', (t) async {
    await pumpRoutedScreen(t, const WelcomeScreen(), overrides: overrides());
    expect(find.text('Citoyen'), findsOneWidget);
    expect(find.text('Collecteur'), findsOneWidget);
    expect(find.text('Recycleur'), findsOneWidget);
    expect(find.text('Administrateur'), findsNothing);

    await tapText(t, 'Collecteur');
    expect(find.text('route:/sign-up?role=collector'), findsOneWidget);
  });

  testWidgets('sign-in shows validation, then clear credential errors with remaining attempts', (
    t,
  ) async {
    auth.passwords['a@b.tn'] = 'recycle26';
    await pumpRoutedScreen(t, const SignInScreen(), overrides: overrides());
    await tapText(t, 'Se connecter');
    expect(find.text('Champ obligatoire'), findsNWidgets(2));

    await t.enterText(find.byType(TextFormField).at(0), 'a@b.tn');
    await t.enterText(find.byType(TextFormField).at(1), 'wrong-pass1');
    await tapText(t, 'Se connecter');
    expect(find.textContaining('E-mail ou mot de passe incorrect.'), findsOneWidget);
    expect(find.textContaining('Encore 4 essais'), findsOneWidget);
  });

  testWidgets('sign-up hides admin, requires consent, creates the profile', (t) async {
    await pumpRoutedScreen(
      t,
      const SignUpScreen(),
      overrides: overrides(),
      size: const Size(420, 1800),
    );
    expect(find.text('Administrateur'), findsNothing);
    expect(find.textContaining('administrateur sont créés'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await t.enterText(fields.at(0), 'Sana Mansour');
    await t.enterText(fields.at(1), 'sana@eco.tn');
    await t.enterText(fields.at(2), 'recycle26');
    await t.enterText(fields.at(3), 'recycle26');
    await tapText(t, 'Recycleur');

    await tapText(t, 'Créer mon compte');
    expect(auth.currentUser, isNull, reason: 'button disabled without consent');

    await t.tap(find.byType(Checkbox));
    await settle(t);
    await tapText(t, 'Créer mon compte');
    final doc = (await db.doc('users/uid-sana@eco.tn').get()).data();
    expect(doc?['role'], 'recycler');
  });

  testWidgets('phone flow: invalid number error, then code step with countdown', (t) async {
    await pumpRoutedScreen(t, const PhoneScreen(), overrides: overrides());
    await t.enterText(find.byType(TextFormField), '123');
    await tapText(t, 'Recevoir le code');
    expect(find.textContaining('Numéro invalide'), findsOneWidget);

    await t.enterText(find.byType(TextFormField), '22 123 456');
    await tapText(t, 'Recevoir le code');
    expect(find.text('Code de vérification'), findsOneWidget);
    expect(find.textContaining('+21622123456'), findsOneWidget);
    expect(find.textContaining('Code valable encore'), findsOneWidget);
    expect(find.textContaining('Renvoyer dans'), findsOneWidget);
  });

  testWidgets('forgot password confirms the link was sent', (t) async {
    await pumpRoutedScreen(t, const ForgotPasswordScreen(), overrides: overrides());
    await t.enterText(find.byType(TextFormField), 'a@b.tn');
    await tapText(t, 'Envoyer le lien');
    expect(auth.sentResets, ['a@b.tn']);
    expect(find.text('Lien envoyé ✅'), findsOneWidget);
  });
}
