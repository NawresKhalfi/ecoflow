import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/storage/local_preferences.dart';
import '../data/auth_repository.dart';
import '../data/login_attempts_store.dart';
import '../data/user_profile_repository.dart';
import '../domain/app_user.dart';
import '../domain/auth_user.dart';
import '../domain/login_lockout_policy.dart';
import '../domain/otp_policy.dart';
import '../domain/session_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);

final userProfileRepositoryProvider = Provider<UserProfileRepository>(
  (ref) => FirestoreUserProfileRepository(ref.watch(firestoreProvider)),
);

final loginAttemptsStoreProvider = Provider<LoginAttemptsStore>(
  (ref) => LoginAttemptsStore(ref.watch(localPreferencesProvider)),
);

final lockoutPolicyProvider = Provider((ref) => const LoginLockoutPolicy());
final otpPolicyProvider = Provider((ref) => const OtpPolicy());

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentUidProvider = Provider<String?>((ref) => ref.watch(authStateProvider).value?.uid);

final currentProfileProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(userProfileRepositoryProvider).watch(uid);
});

final sessionProvider = Provider<SessionState>((ref) {
  final auth = ref.watch(authStateProvider);
  final profile = ref.watch(currentProfileProvider);
  return computeSession(
    authLoaded: auth.hasValue || auth.hasError,
    authUser: auth.value,
    profileLoaded: profile.hasValue || profile.hasError,
    profile: profile.value,
  );
});
