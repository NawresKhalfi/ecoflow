import 'dart:async';

import 'package:ecoflow/features/auth/data/auth_repository.dart';
import 'package:ecoflow/features/auth/domain/auth_failure.dart';
import 'package:ecoflow/features/auth/domain/auth_user.dart';

/// Authentification en mémoire pour les tests.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser}) : _user = initialUser;

  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _user;

  final passwords = <String, String>{};
  final verifiedEmails = <String>{};
  final sentResets = <String>[];
  final sentCodes = <String>[];
  String validSmsCode = '123456';
  AuthFailure? failNextWith;
  bool recentLogin = true;
  bool deleted = false;
  int verificationEmails = 0;

  void emit(AuthUser? u) {
    _user = u;
    _changes.add(u);
  }

  void _maybeFail() {
    final f = failNextWith;
    if (f != null) {
      failNextWith = null;
      throw f;
    }
  }

  AuthUser _emailUser(String email) => AuthUser(
        uid: 'uid-$email',
        email: email,
        emailVerified: verifiedEmails.contains(email),
        providerIds: const ['password'],
      );

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    _maybeFail();
    if (passwords[email.trim()] != password) {
      throw const AuthFailure(AuthFailureCode.wrongCredentials);
    }
    emit(_emailUser(email.trim()));
  }

  @override
  Future<void> signUpWithEmail(String email, String password, String displayName) async {
    _maybeFail();
    if (passwords.containsKey(email)) throw const AuthFailure(AuthFailureCode.emailInUse);
    passwords[email] = password;
    verificationEmails++;
    emit(_emailUser(email));
  }

  @override
  Future<void> sendEmailVerification() async => verificationEmails++;

  @override
  Future<bool> reloadEmailVerified() async {
    final u = _user;
    if (u?.email == null) return false;
    return verifiedEmails.contains(u!.email);
  }

  @override
  Future<void> signInWithGoogle() async {
    _maybeFail();
    emit(const AuthUser(uid: 'uid-google', email: 'g@x.tn', emailVerified: true, providerIds: ['google.com']));
  }

  @override
  Future<PhoneCodeResult> sendPhoneCode(String e164Phone) async {
    _maybeFail();
    sentCodes.add(e164Phone);
    return PhoneCodeSent('vid-${sentCodes.length}');
  }

  @override
  Future<void> confirmPhoneCode(String verificationId, String smsCode) async {
    _maybeFail();
    if (smsCode != validSmsCode) throw const AuthFailure(AuthFailureCode.invalidCode);
    emit(AuthUser(uid: 'uid-phone', phoneNumber: sentCodes.last, providerIds: const ['phone']));
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _maybeFail();
    sentResets.add(email);
  }

  @override
  Future<void> ensureRecentLogin({String? password}) async {
    final u = _user;
    if (u == null) throw const AuthFailure(AuthFailureCode.unknown);
    if (u.usesPassword && passwords[u.email] != password) {
      throw const AuthFailure(AuthFailureCode.wrongCredentials);
    }
    if (!u.usesPassword && !recentLogin) {
      throw const AuthFailure(AuthFailureCode.requiresRecentLogin);
    }
  }

  @override
  Future<void> deleteCurrentUser() async => deleted = true;

  @override
  Future<void> signOut() async => emit(null);
}
