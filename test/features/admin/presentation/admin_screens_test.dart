import 'package:ecoflow/core/firebase/firebase_providers.dart';
import 'package:ecoflow/features/admin/presentation/screens/broadcast_screen.dart';
import 'package:ecoflow/features/admin/presentation/screens/disputes_screen.dart';
import 'package:ecoflow/features/admin/presentation/screens/supervision_screen.dart';
import 'package:ecoflow/features/admin/presentation/screens/users_admin_screen.dart';
import 'package:ecoflow/features/admin/presentation/screens/verifications_screen.dart';
import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/auth/presentation/screens/blocked_screen.dart';
import 'package:ecoflow/features/tracking/presentation/screens/inbox_screen.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_auth_repository.dart';
import '../../../helpers/test_app.dart';

final now = DateTime(2026, 10, 1, 9);

void main() {
  late FakeFirebaseFirestore db;

  Future<List<Override>> as(String uid, Map<String, Object?> profile) async {
    await db.doc('users/$uid').set({'displayName': uid, 'status': 'active', ...profile});
    return [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          initialUser: AuthUser(
            uid: uid,
            phoneNumber: '+21622000033',
            providerIds: const ['phone'],
          ),
        ),
      ),
      firestoreProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(() => now),
    ];
  }

  Future<void> pumpIt(WidgetTester t, Widget w, List<Override> o) async {
    await pumpRoutedScreen(t, w, overrides: o, size: const Size(420, 2600));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
    await settle(t);
  }

  Future<void> act(WidgetTester t, String label) async {
    await t.ensureVisible(find.text(label).first);
    await t.tap(find.text(label).first);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
    await settle(t);
  }

  setUp(() => db = FakeFirebaseFirestore());

  testWidgets('supervision: tonnes, CO₂ and service performance (US-109 to US-111)', (t) async {
    final o = await as('admin', {'role': 'admin'});
    await db.doc('estimates/E1').set({
      'status': 'weighed',
      'actualKg': {'pet_bottle': 600.0, 'can': 400.0},
      'totalKg': 1000.0,
    });
    await db.doc('collections/c1').set({
      'citizenUid': 'c',
      'collectorUid': 'k',
      'estimateCode': 'E1',
      'status': 'completed',
      'estimatedKg': 1000.0,
      'createdAt': now.subtract(const Duration(days: 3)),
      'acceptedAt': now.subtract(const Duration(days: 3, minutes: -45)),
      'completedAt': now.subtract(const Duration(days: 2)),
      'place': {'zoneId': 'sousse', 'address': 'Rue'},
    });
    await pumpIt(t, const SupervisionScreen(), o);
    expect(find.text('1,00'), findsOneWidget, reason: '1 tonne');
    expect(
      find.textContaining(RegExp(r'4\s500')),
      findsOneWidget,
      reason: '600 × 1,5 + 400 × 9 kg CO₂e',
    );
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('100 %'), findsWidgets, reason: 'matching rate and AI accuracy');
    expect(find.text('Administrateurs'), findsOneWidget, reason: 'super admin tools');
  });

  testWidgets('delegated admin only sees its tools (US-113)', (t) async {
    final o = await as('mod', {
      'role': 'admin',
      'adminPermissions': ['disputes'],
    });
    await pumpIt(t, const SupervisionScreen(), o);
    expect(find.text('Litiges'), findsOneWidget);
    expect(find.text('Comptes'), findsNothing);
    expect(find.text('Administrateurs'), findsNothing);
  });

  testWidgets('block an account with a reason (US-106)', (t) async {
    final o = await as('admin', {'role': 'admin'});
    await db.doc('users/leila').set({
      'displayName': 'Leila Trabelsi',
      'role': 'citizen',
      'status': 'active',
      'email': 'leila@ecoflow.tn',
    });
    await pumpIt(t, const UsersAdminScreen(), o);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Rechercher (nom, e-mail, téléphone)'),
      'trab',
    );
    await settle(t);
    expect(find.text('1 compte'), findsOneWidget);
    await act(t, 'Leila Trabelsi');
    await t.enterText(
      find.widgetWithText(TextFormField, 'Motif (affiché à l’utilisateur)'),
      'Fraude',
    );
    await act(t, 'Bloquer le compte');
    expect((await db.doc('users/leila').get()).data()!['status'], 'blocked');
    expect((await db.collection('auditLog').get()).docs.single.data()['action'], 'user.block');
  });

  testWidgets('approve a collector application (US-107)', (t) async {
    final o = await as('admin', {'role': 'admin'});
    await db.doc('users/karim').set({
      'displayName': 'Karim',
      'role': 'collector',
      'status': 'active',
      'verificationStatus': 'pending',
    });
    await pumpIt(t, const VerificationsScreen(), o);
    expect(find.text('Karim'), findsOneWidget);
    await act(t, 'Valider');
    expect((await db.doc('users/karim').get()).data()!['verificationStatus'], 'approved');
  });

  testWidgets('settle a dispute (US-112)', (t) async {
    final o = await as('admin', {'role': 'admin'});
    await db.doc('tickets/t1').set({
      'collectionId': 'col1',
      'reporterUid': 'leila',
      'reason': 'collectorAbsent',
      'description': 'Le collecteur n’est pas venu',
      'status': 'open',
      'createdAt': now.subtract(const Duration(days: 2)),
    });
    await pumpIt(t, const DisputesScreen(), o);
    expect(find.textContaining('ouvert depuis 2 j'), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Décision (envoyée au signalant)'),
      'Collecte reprogrammée',
    );
    await act(t, 'Fondé');
    expect((await db.doc('tickets/t1').get()).data()!['status'], 'resolved');
  });

  testWidgets('announcement reaches the targeted inbox only (US-116)', (t) async {
    final admin = await as('admin', {'role': 'admin'});
    await pumpIt(t, const BroadcastScreen(), admin);
    await t.enterText(find.widgetWithText(TextFormField, 'Titre'), 'Nouvelle zone');
    await t.enterText(find.widgetWithText(TextFormField, 'Message'), 'Monastir est desservie');
    await act(t, 'Collecteur');
    await act(t, 'Envoyer l’annonce');
    final ann = (await db.collection('announcements').get()).docs.single.data();
    expect((ann['title'], ann['role']), ('Nouvelle zone', 'collector'));

    final collector = await as('karim', {'role': 'collector'});
    await pumpIt(t, const InboxScreen(), collector);
    expect(find.textContaining('Nouvelle zone'), findsOneWidget);
    final citizen = await as('leila', {'role': 'citizen'});
    await pumpIt(t, const InboxScreen(), citizen);
    expect(find.textContaining('Nouvelle zone'), findsNothing);
  });

  testWidgets('blocked user sees the reason', (t) async {
    final o = await as('leila', {
      'role': 'citizen',
      'status': 'blocked',
      'blockedReason': 'Fraude aux points',
    });
    await pumpIt(t, const BlockedScreen(), o);
    expect(find.textContaining('Fraude aux points'), findsOneWidget);
    expect(find.text('Compte suspendu'), findsOneWidget);
  });
}
