import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:ecoflow/features/auth/presentation/screens/welcome_screen.dart';
import 'package:ecoflow/features/impact/presentation/screens/impact_screen.dart';
import 'package:ecoflow/features/impact/presentation/screens/tips_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_repository.dart';
import '../helpers/test_app.dart';

/// Audit d'accessibilité de base (US-129) : contraste du texte, cibles
/// tactiles (48 dp Android, 44 pt iOS) et libellés des éléments actifs.
Future<void> audit(WidgetTester t) async {
  await expectLater(t, meetsGuideline(textContrastGuideline));
  await expectLater(t, meetsGuideline(androidTapTargetGuideline));
  await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
}

void main() {
  late FakeFirebaseFirestore db;
  setUp(() => db = FakeFirebaseFirestore());

  List<Override> citizen() => [
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(
        initialUser: const AuthUser(uid: 'leila', phoneNumber: '+216', providerIds: ['phone']),
      ),
    ),
    firestoreProvider.overrideWithValue(db),
  ];

  for (final (name, screen, signedIn) in [
    ('welcome', const WelcomeScreen(), false),
    ('sign in', const SignInScreen(), false),
    ('impact', const ImpactScreen(), true),
    ('sorting tips', const TipsScreen(), true),
    ('tip sheet', const TipSheetScreen(sheetName: 'glass'), true),
  ]) {
    testWidgets('accessibility audit: $name', (t) async {
      final handle = t.ensureSemantics();
      await pumpRoutedScreen(
        t,
        screen,
        overrides: signedIn ? citizen() : [firestoreProvider.overrideWithValue(db)],
        size: const Size(400, 2400),
      );
      await settle(t);
      await audit(t);
      handle.dispose();
    });
  }
}
