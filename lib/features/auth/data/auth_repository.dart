import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';

/// Résultat de l'envoi d'un code SMS.
sealed class PhoneCodeResult {
  const PhoneCodeResult();
}

class PhoneCodeSent extends PhoneCodeResult {
  const PhoneCodeSent(this.verificationId);
  final String verificationId;
}

/// Android a lu le SMS automatiquement : l'utilisateur est déjà connecté.
class PhoneAutoVerified extends PhoneCodeResult {
  const PhoneAutoVerified();
}

/// Contrat d'authentification, indépendant de Firebase pour les tests.
abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;

  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String email, String password, String displayName);
  Future<void> sendEmailVerification();

  /// Recharge l'utilisateur et indique si son e-mail est vérifié.
  Future<bool> reloadEmailVerified();

  Future<void> signInWithGoogle();
  Future<PhoneCodeResult> sendPhoneCode(String e164Phone);
  Future<void> confirmPhoneCode(String verificationId, String smsCode);
  Future<void> sendPasswordReset(String email);
  /// Ré-authentifie l'utilisateur avant une action sensible : mot de passe
  /// pour les comptes e-mail, Google à nouveau, ou connexion récente (téléphone).
  Future<void> ensureRecentLogin({String? password});
  Future<void> deleteCurrentUser();
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;
  bool _googleReady = false;
  final Map<String, ConfirmationResult> _webConfirmations = {};

  static AuthUser? _map(User? u) => u == null
      ? null
      : AuthUser(
          uid: u.uid,
          email: u.email,
          phoneNumber: u.phoneNumber,
          displayName: u.displayName,
          emailVerified: u.emailVerified,
          providerIds: u.providerData.map((p) => p.providerId).toList(),
        );

  /// Exécute [action] en convertissant les erreurs Firebase en [AuthFailure].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(mapFirebaseAuthCode(e.code));
    } on GoogleSignInException catch (e) {
      throw AuthFailure(e.code == GoogleSignInExceptionCode.canceled
          ? AuthFailureCode.cancelled
          : AuthFailureCode.providerUnavailable);
    }
  }

  @override
  Stream<AuthUser?> authStateChanges() => _auth.userChanges().map(_map);

  @override
  AuthUser? get currentUser => _map(_auth.currentUser);

  @override
  Future<void> signInWithEmail(String email, String password) => _guard(() =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> signUpWithEmail(String email, String password, String displayName) =>
      _guard(() async {
        final cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);
        await cred.user?.updateDisplayName(displayName.trim());
        await cred.user?.sendEmailVerification();
      });

  @override
  Future<void> sendEmailVerification() =>
      _guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<bool> reloadEmailVerified() => _guard(() async {
        await _auth.currentUser?.reload();
        return _auth.currentUser?.emailVerified ?? false;
      });

  @override
  Future<void> signInWithGoogle() => _guard(() async {
        if (kIsWeb) {
          await _auth.signInWithPopup(GoogleAuthProvider());
          return;
        }
        await _auth.signInWithCredential(
            GoogleAuthProvider.credential(idToken: await _googleIdToken()));
      });

  Future<String?> _googleIdToken() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize();
      _googleReady = true;
    }
    final account = await google.authenticate();
    return account.authentication.idToken;
  }

  @override
  Future<PhoneCodeResult> sendPhoneCode(String e164Phone) => _guard(() async {
        if (kIsWeb) {
          final confirmation = await _auth.signInWithPhoneNumber(e164Phone);
          _webConfirmations[confirmation.verificationId] = confirmation;
          return PhoneCodeSent(confirmation.verificationId);
        }
        final completer = Completer<PhoneCodeResult>();
        await _auth.verifyPhoneNumber(
          phoneNumber: e164Phone,
          timeout: const Duration(seconds: 60),
          verificationCompleted: (credential) async {
            if (completer.isCompleted) return;
            try {
              await _auth.signInWithCredential(credential);
              completer.complete(const PhoneAutoVerified());
            } on FirebaseAuthException catch (e) {
              completer.completeError(AuthFailure(mapFirebaseAuthCode(e.code)));
            }
          },
          verificationFailed: (e) {
            if (!completer.isCompleted) {
              completer.completeError(AuthFailure(mapFirebaseAuthCode(e.code)));
            }
          },
          codeSent: (verificationId, _) {
            if (!completer.isCompleted) completer.complete(PhoneCodeSent(verificationId));
          },
          codeAutoRetrievalTimeout: (_) {},
        );
        return completer.future;
      });

  @override
  Future<void> confirmPhoneCode(String verificationId, String smsCode) =>
      _guard(() async {
        final web = _webConfirmations.remove(verificationId);
        if (web != null) {
          await web.confirm(smsCode);
          return;
        }
        await _auth.signInWithCredential(PhoneAuthProvider.credential(
            verificationId: verificationId, smsCode: smsCode));
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> ensureRecentLogin({String? password}) => _guard(() async {
        final user = _auth.currentUser;
        if (user == null) throw const AuthFailure(AuthFailureCode.unknown);
        final providers = user.providerData.map((p) => p.providerId).toSet();
        if (providers.contains('password')) {
          await user.reauthenticateWithCredential(
              EmailAuthProvider.credential(email: user.email!, password: password ?? ''));
        } else if (providers.contains('google.com') && !kIsWeb) {
          await user.reauthenticateWithCredential(
              GoogleAuthProvider.credential(idToken: await _googleIdToken()));
        } else {
          final last = user.metadata.lastSignInTime;
          if (last == null || DateTime.now().difference(last) > const Duration(minutes: 5)) {
            throw const AuthFailure(AuthFailureCode.requiresRecentLogin);
          }
        }
      });

  @override
  Future<void> deleteCurrentUser() => _guard(() async => _auth.currentUser?.delete());

  @override
  Future<void> signOut() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }
}
