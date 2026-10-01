import 'app_user.dart';
import 'auth_user.dart';
import 'user_role.dart';

/// `blocked` : compte bloqué par l'administration (US-106).
enum SessionStatus { loading, signedOut, needsEmailVerification, needsProfile, blocked, ready }

/// État de session consolidé (auth + profil) qui pilote la navigation.
class SessionState {
  const SessionState(this.status, {this.authUser, this.profile});

  final SessionStatus status;
  final AuthUser? authUser;
  final AppUser? profile;

  UserRole? get role => profile?.role;

  static const loading = SessionState(SessionStatus.loading);
  static const signedOut = SessionState(SessionStatus.signedOut);
}

/// Combine l'utilisateur authentifié et son profil Firestore.
/// `profileLoaded` vaut `false` tant que le profil n'a pas été lu.
SessionState computeSession({
  required bool authLoaded,
  required AuthUser? authUser,
  required bool profileLoaded,
  required AppUser? profile,
}) {
  if (!authLoaded) return SessionState.loading;
  if (authUser == null) return SessionState.signedOut;
  if (authUser.needsEmailVerification) {
    return SessionState(SessionStatus.needsEmailVerification, authUser: authUser);
  }
  if (!profileLoaded) return SessionState(SessionStatus.loading, authUser: authUser);
  if (profile == null) return SessionState(SessionStatus.needsProfile, authUser: authUser);
  if (profile.blocked) {
    return SessionState(SessionStatus.blocked, authUser: authUser, profile: profile);
  }
  return SessionState(SessionStatus.ready, authUser: authUser, profile: profile);
}
