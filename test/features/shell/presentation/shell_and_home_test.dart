import 'package:ecoflow/features/auth/application/auth_providers.dart';
import 'package:ecoflow/features/auth/domain/app_user.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';
import 'package:ecoflow/features/auth/domain/session_state.dart';
import 'package:ecoflow/features/auth/domain/user_role.dart';
import 'package:ecoflow/features/auth/domain/verification_status.dart';
import 'package:ecoflow/features/shell/domain/nav_destinations.dart';
import 'package:ecoflow/features/shell/presentation/screens/home_screen.dart';
import 'package:ecoflow/features/shell/presentation/widgets/role_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/test_app.dart';

SessionState session(
  UserRole role, {
  VerificationStatus status = VerificationStatus.notRequired,
  String? reason,
}) => SessionState(
  SessionStatus.ready,
  authUser: const AuthUser(uid: 'u'),
  profile: AppUser(
    uid: 'u',
    displayName: 'Karim Ben Salah',
    role: role,
    email: 'k@eco.tn',
    verificationStatus: status,
    rejectionReason: reason,
  ),
);

void main() {
  test('each role gets its own navigation', () {
    expect(destinationsFor(UserRole.citizen), contains(NavDestination.collections));
    expect(destinationsFor(UserRole.collector), contains(NavDestination.documents));
    expect(
      destinationsFor(UserRole.recycler),
      containsAll([NavDestination.dashboard, NavDestination.stock]),
    );
    expect(destinationsFor(UserRole.admin), [
      NavDestination.home,
      NavDestination.catalog,
      NavDestination.model,
      NavDestination.pricing,
      NavDestination.profile,
    ]);
    expect(
      destinationsFor(UserRole.collector),
      containsAll([NavDestination.missions, NavDestination.earnings]),
    );
    expect(destinationsFor(UserRole.recycler), contains(NavDestination.receptions));
    expect(destinationsFor(UserRole.citizen), contains(NavDestination.wallet));
    expect(destinationsFor(UserRole.citizen), contains(NavDestination.scan));
    expect(destinationsFor(UserRole.collector), isNot(contains(NavDestination.scan)));
    final items = destinationsFor(UserRole.citizen);
    expect(activeDestination(items, '/app/collections/abc'), NavDestination.collections);
    expect(activeDestination(items, '/app'), NavDestination.home);
    expect(activeDestination(items, '/app/wallet/coupons'), NavDestination.wallet);
  });

  Widget shell() => const RoleShell(location: '/app', child: HomeScreen());

  testWidgets('mobile: floating bottom navigation', (t) async {
    await pumpRoutedScreen(
      t,
      shell(),
      overrides: [sessionProvider.overrideWithValue(session(UserRole.citizen))],
    );
    expect(find.text('Bonjour Karim 👋'), findsOneWidget);
    expect(find.text('Collectes'), findsOneWidget);
    expect(find.text('Dossier'), findsNothing);
    expect(find.textContaining('Flow'), findsNothing, reason: 'logo only in the side bar');
    expect(find.text('kg recyclés'), findsOneWidget);
  });

  testWidgets('desktop: side navigation with logo', (t) async {
    await pumpRoutedScreen(
      t,
      shell(),
      size: const Size(1280, 900),
      overrides: [sessionProvider.overrideWithValue(session(UserRole.collector))],
    );
    expect(find.text('Dossier'), findsOneWidget);
    expect(find.text('Collectes'), findsNothing);
    expect(find.byType(RoleShell), findsOneWidget);
    expect(find.textContaining('Eco'), findsWidgets);
  });

  testWidgets('rejected collector sees the reason and can fix the file', (t) async {
    await pumpRoutedScreen(
      t,
      shell(),
      overrides: [
        sessionProvider.overrideWithValue(
          session(
            UserRole.collector,
            status: VerificationStatus.rejected,
            reason: 'Permis illisible',
          ),
        ),
      ],
    );
    expect(find.text('Motif : Permis illisible'), findsOneWidget);
    expect(find.text('✕ Refusé'), findsWidgets);
    await t.ensureVisible(find.text('Compléter mon dossier'));
    await t.tap(find.text('Compléter mon dossier'));
    await settle(t);
    expect(find.text('route:/app/documents'), findsOneWidget);
  });

  testWidgets('pending recycler cannot resubmit', (t) async {
    await pumpRoutedScreen(
      t,
      shell(),
      overrides: [
        sessionProvider.overrideWithValue(
          session(UserRole.recycler, status: VerificationStatus.pending),
        ),
      ],
    );
    expect(find.text('⏳ En attente'), findsOneWidget);
    expect(find.text('Compléter mon entreprise'), findsNothing);
  });

  testWidgets('home can be scoped with ProviderScope overrides', (t) async {
    await pumpScreen(
      t,
      const HomeScreen(),
      overrides: [sessionProvider.overrideWithValue(session(UserRole.admin))],
    );
    expect(find.text('Vue globale de la plateforme EcoFlow.'), findsOneWidget);
    expect(find.byType(ProviderScope), findsOneWidget);
  });
}
