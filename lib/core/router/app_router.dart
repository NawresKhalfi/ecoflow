import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/screens/complete_profile_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/phone_screen.dart';
import '../../features/auth/presentation/screens/privacy_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/profile/presentation/screens/address_form_screen.dart';
import '../../features/profile/presentation/screens/addresses_screen.dart';
import '../../features/profile/presentation/screens/company_screen.dart';
import '../../features/profile/presentation/screens/delete_account_screen.dart';
import '../../features/profile/presentation/screens/documents_screen.dart';
import '../../features/profile/presentation/screens/language_screen.dart';
import '../../features/profile/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/collection/presentation/screens/collection_detail_screen.dart';
import '../../features/collection/presentation/screens/collections_screen.dart';
import '../../features/collection/presentation/screens/request_form_screen.dart';
import '../../features/estimation/presentation/screens/estimates_screen.dart';
import '../../features/estimation/presentation/screens/pricing_screen.dart';
import '../../features/estimation/presentation/screens/weighing_screen.dart';
import '../../features/missions/presentation/screens/deposit_screen.dart';
import '../../features/missions/presentation/screens/earnings_screen.dart';
import '../../features/missions/presentation/screens/mission_detail_screen.dart';
import '../../features/missions/presentation/screens/missions_screen.dart';
import '../../features/missions/presentation/screens/receptions_screen.dart';
import '../../features/missions/presentation/screens/vehicle_screen.dart';
import '../../features/routing/presentation/screens/optimization_screen.dart';
import '../../features/routing/presentation/screens/tour_screen.dart';
import '../../features/scan/presentation/screens/scan_screen.dart';
import '../../features/tracking/presentation/screens/chat_screen.dart';
import '../../features/tracking/presentation/screens/inbox_screen.dart';
import '../../features/shell/presentation/screens/home_screen.dart';
import '../../features/vision_admin/presentation/screens/catalog_screen.dart';
import '../../features/wallet/presentation/screens/coupons_screen.dart';
import '../../features/wallet/presentation/screens/fraud_screen.dart';
import '../../features/wallet/presentation/screens/points_rules_screen.dart';
import '../../features/wallet/presentation/screens/rewards_admin_screen.dart';
import '../../features/wallet/presentation/screens/rewards_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/vision_admin/presentation/screens/model_screen.dart';
import '../../features/shell/presentation/screens/splash_screen.dart';
import '../../features/shell/presentation/widgets/role_shell.dart';
import 'route_guard.dart';
import 'routes.dart';

/// Transition douce entre les onglets de l'espace connecté.
Page<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage(
  key: state.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 280),
  transitionsBuilder: (context, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  ),
);

GoRoute _tab(
  String path,
  Widget Function(GoRouterState) build, {
  List<RouteBase> routes = const [],
}) => GoRoute(path: path, pageBuilder: (_, s) => _fade(s, build(s)), routes: routes);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (_, state) => resolveRedirect(ref.read(sessionProvider), state.uri.path),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: Routes.signIn, builder: (_, _) => const SignInScreen()),
      GoRoute(
        path: Routes.signUp,
        builder: (_, s) =>
            SignUpScreen(initialRole: UserRole.fromName(s.uri.queryParameters['role'])),
      ),
      GoRoute(path: Routes.phone, builder: (_, _) => const PhoneScreen()),
      GoRoute(path: Routes.forgotPassword, builder: (_, _) => const ForgotPasswordScreen()),
      GoRoute(path: Routes.verifyEmail, builder: (_, _) => const VerifyEmailScreen()),
      GoRoute(path: Routes.completeProfile, builder: (_, _) => const CompleteProfileScreen()),
      GoRoute(path: Routes.privacy, builder: (_, _) => const PrivacyScreen()),
      GoRoute(path: Routes.language, builder: (_, _) => const LanguageScreen()),
      ShellRoute(
        builder: (_, state, child) => RoleShell(location: state.uri.path, child: child),
        routes: [
          _tab(
            Routes.home,
            (_) => const HomeScreen(),
            routes: [
              _tab('profile', (_) => const ProfileScreen()),
              _tab('scan', (_) => const ScanScreen()),
              _tab('catalog', (_) => const CatalogScreen()),
              _tab('model', (_) => const ModelScreen()),
              _tab(
                'estimates',
                (_) => const EstimatesScreen(),
                routes: [
                  _tab(':code', (s) => EstimateDetailScreen(code: s.pathParameters['code']!)),
                ],
              ),
              _tab('weighing', (_) => const WeighingScreen()),
              _tab(
                'missions',
                (_) => const MissionsScreen(),
                routes: [
                  _tab('tour', (_) => const TourScreen()),
                  _tab(':id', (s) => MissionDetailScreen(id: s.pathParameters['id']!)),
                ],
              ),
              _tab(
                'earnings',
                (_) => const EarningsScreen(),
                routes: [_tab('deposit', (_) => const DepositScreen())],
              ),
              _tab('vehicle', (_) => const VehicleScreen()),
              _tab('receptions', (_) => const ReceptionsScreen()),
              _tab('optimization', (_) => const OptimizationScreen()),
              _tab('inbox', (_) => const InboxScreen()),
              _tab(
                'wallet',
                (_) => const WalletScreen(),
                routes: [
                  _tab('rewards', (_) => const RewardsScreen()),
                  _tab('coupons', (_) => const CouponsScreen()),
                ],
              ),
              _tab('points-rules', (_) => const PointsRulesScreen()),
              _tab('rewards-admin', (_) => const RewardsAdminScreen()),
              _tab('fraud', (_) => const FraudScreen()),
              _tab('chat/:id', (s) => ChatScreen(collectionId: s.pathParameters['id']!)),
              _tab(
                'collections',
                (_) => const CollectionsScreen(),
                routes: [
                  _tab(
                    'new/:code',
                    (s) => RequestFormScreen(estimateCode: s.pathParameters['code']!),
                  ),
                  _tab(':id', (s) => CollectionDetailScreen(id: s.pathParameters['id']!)),
                ],
              ),
              _tab('pricing', (_) => const PricingScreen()),
              _tab(
                'addresses',
                (_) => const AddressesScreen(),
                routes: [
                  _tab('new', (_) => const AddressFormScreen()),
                  _tab(':id', (s) => AddressFormScreen(addressId: s.pathParameters['id'])),
                ],
              ),
              _tab('documents', (_) => const DocumentsScreen()),
              _tab('company', (_) => const CompanyScreen()),
              _tab('notifications', (_) => const NotificationsScreen()),
              _tab('delete-account', (_) => const DeleteAccountScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
