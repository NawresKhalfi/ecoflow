import '../../features/auth/domain/session_state.dart';
import '../../features/auth/domain/user_role.dart';
import 'routes.dart';

/// Écrans réservés à un rôle (US-003 : le rôle détermine la navigation).
const _roleOnly = {
  Routes.addresses: UserRole.citizen,
  Routes.documents: UserRole.collector,
  Routes.company: UserRole.recycler,
  Routes.scan: UserRole.citizen,
  Routes.catalog: UserRole.admin,
  Routes.model: UserRole.admin,
  Routes.estimates: UserRole.citizen,
  Routes.collections: UserRole.citizen,
  Routes.missions: UserRole.collector,
  Routes.earnings: UserRole.collector,
  Routes.vehicle: UserRole.collector,
  Routes.receptions: UserRole.recycler,
  Routes.optimization: UserRole.admin,
  Routes.weighing: UserRole.collector,
  Routes.pricing: UserRole.admin,
  Routes.wallet: UserRole.citizen,
  Routes.pointsRules: UserRole.admin,
  Routes.rewardsAdmin: UserRole.admin,
  Routes.fraud: UserRole.admin,
};

/// Redirection de navigation, fonction pure testée unitairement.
/// Renvoie `null` si [location] est autorisée dans l'état [s].
String? resolveRedirect(SessionState s, String location) {
  if (s.status == SessionStatus.loading) {
    return location == Routes.splash ? null : Routes.splash;
  }
  if (Routes.always.contains(location)) return null;
  switch (s.status) {
    case SessionStatus.signedOut:
      return Routes.public.contains(location) ? null : Routes.welcome;
    case SessionStatus.needsEmailVerification:
      return location == Routes.verifyEmail ? null : Routes.verifyEmail;
    case SessionStatus.needsProfile:
      // Le numéro vient d'être vérifié : l'écran téléphone laisse la place.
      return location == Routes.completeProfile ? null : Routes.completeProfile;
    case SessionStatus.ready:
      if (!location.startsWith(Routes.home)) return Routes.home;
      for (final MapEntry(key: path, value: role) in _roleOnly.entries) {
        final inside = location == path || location.startsWith('$path/');
        if (inside && s.role != role) return Routes.home;
      }
      return null;
    case SessionStatus.loading:
      return Routes.splash;
  }
}
