import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/profile/domain/notification_preferences.dart';
import 'package:ecoflow/features/profile/presentation/screens/delete_account_screen.dart';
import 'package:ecoflow/features/profile/presentation/screens/documents_screen.dart';
import 'package:ecoflow/features/profile/presentation/screens/notifications_screen.dart';
import 'package:ecoflow/features/profile/presentation/screens/profile_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

void main() {
  late FakeFirebaseFirestore db;
  late FakeAuthRepository auth;

  Future<List<Override>> signedIn(String role) async {
    db = FakeFirebaseFirestore();
    auth = FakeAuthRepository(
      initialUser: const AuthUser(
        uid: 'u',
        email: 'a@b.tn',
        emailVerified: true,
        providerIds: ['password'],
      ),
    );
    await db.doc('users/u').set({
      'displayName': 'Amine Ben Ali',
      'role': role,
      'email': 'a@b.tn',
      'verificationStatus': role == 'citizen' ? 'notRequired' : 'notSubmitted',
      'notificationPreferences': NotificationPreferences.defaults.toMap(),
      'status': 'active',
    });
    return [
      authRepositoryProvider.overrideWithValue(auth),
      firestoreProvider.overrideWithValue(db),
    ];
  }

  testWidgets('profile menu adapts to the role', (t) async {
    await pumpRoutedScreen(
      t,
      const ProfileScreen(),
      overrides: await signedIn('citizen'),
      size: const Size(420, 1600),
    );
    await settle(t);
    expect(find.text('Amine Ben Ali'), findsOneWidget);
    expect(find.text('Mes adresses'), findsOneWidget);
    expect(find.text('Mon dossier collecteur'), findsNothing);
    expect(find.text('Supprimer mon compte'), findsOneWidget);
  });

  testWidgets('notification switches write the preferences', (t) async {
    await pumpRoutedScreen(t, const NotificationsScreen(), overrides: await signedIn('citizen'));
    await settle(t);
    expect(find.byType(Switch), findsNWidgets(3));
    await t.tap(find.byType(Switch).last);
    await settle(t);
    final prefs = (await db.doc('users/u').get()).data()!['notificationPreferences'];
    expect(prefs['marketplace'], isFalse);
  });

  testWidgets('collector file lists the 4 required documents', (t) async {
    await pumpRoutedScreen(
      t,
      const DocumentsScreen(),
      overrides: await signedIn('collector'),
      size: const Size(420, 1600),
    );
    await settle(t);
    for (final label in [
      'Carte d’identité (CIN)',
      'Permis de conduire',
      'Carte grise',
      'Photo du véhicule',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('0/4 pièces'), findsOneWidget);
    expect(find.text('Ajoute les 4 pièces pour envoyer ton dossier.'), findsOneWidget);
  });

  testWidgets('delete account: step 2 only after typing SUPPRIMER', (t) async {
    await pumpRoutedScreen(
      t,
      const DeleteAccountScreen(),
      overrides: await signedIn('citizen'),
      size: const Size(420, 1400),
    );
    await settle(t);
    await t.tap(find.text('Continuer'));
    await settle(t);
    expect(find.text('Étape 1/2 · Ce qui va se passer'), findsOneWidget);

    await t.enterText(find.byType(TextFormField), 'supprimer');
    await settle(t);
    await t.tap(find.text('Continuer'));
    await settle(t);
    expect(find.text('Étape 2/2 · Confirme ton identité'), findsOneWidget);
    expect(find.text('Mot de passe'), findsOneWidget);
  });
}
