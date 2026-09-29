import '../../../core/router/routes.dart';
import '../../auth/domain/user_role.dart';

enum NavDestination {
  home,
  scan,
  collections,
  estimates,
  weighing,
  addresses,
  documents,
  company,
  catalog,
  model,
  pricing,
  profile,
}

extension NavDestinationRoute on NavDestination {
  String get route => switch (this) {
    NavDestination.home => Routes.home,
    NavDestination.scan => Routes.scan,
    NavDestination.estimates => Routes.estimates,
    NavDestination.collections => Routes.collections,
    NavDestination.weighing => Routes.weighing,
    NavDestination.pricing => Routes.pricing,
    NavDestination.catalog => Routes.catalog,
    NavDestination.model => Routes.model,
    NavDestination.addresses => Routes.addresses,
    NavDestination.documents => Routes.documents,
    NavDestination.company => Routes.company,
    NavDestination.profile => Routes.profile,
  };

  String get emoji => switch (this) {
    NavDestination.home => '🏠',
    NavDestination.scan => '📸',
    NavDestination.estimates => '🧾',
    NavDestination.collections => '🚚',
    NavDestination.weighing => '⚖️',
    NavDestination.pricing => '💰',
    NavDestination.catalog => '🗂️',
    NavDestination.model => '🧠',
    NavDestination.addresses => '📍',
    NavDestination.documents => '🪪',
    NavDestination.company => '🏭',
    NavDestination.profile => '🙂',
  };
}

/// Navigation propre à chaque rôle (US-003). Les epics suivants ajouteront
/// leurs onglets ici (missions, stocks, pilotage…).
List<NavDestination> destinationsFor(UserRole role) => switch (role) {
  UserRole.citizen => const [
    NavDestination.home,
    NavDestination.scan,
    NavDestination.collections,
    NavDestination.estimates,
    NavDestination.profile,
  ],
  UserRole.collector => const [
    NavDestination.home,
    NavDestination.weighing,
    NavDestination.documents,
    NavDestination.profile,
  ],
  UserRole.recycler => const [NavDestination.home, NavDestination.company, NavDestination.profile],
  UserRole.admin => const [
    NavDestination.home,
    NavDestination.catalog,
    NavDestination.model,
    NavDestination.pricing,
    NavDestination.profile,
  ],
};

/// Onglet actif pour un chemin donné (le plus long préfixe correspondant).
NavDestination? activeDestination(List<NavDestination> items, String location) {
  NavDestination? best;
  for (final d in items) {
    final r = d.route;
    final matches = location == r || location.startsWith('$r/');
    if (matches && (best == null || r.length > best.route.length)) best = d;
  }
  return best;
}
