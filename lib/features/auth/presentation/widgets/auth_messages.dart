import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/l10n.dart';
import '../../application/sign_up_controller.dart';
import '../../domain/auth_failure.dart';
import '../../domain/user_role.dart';
import '../../domain/validators.dart';

/// Traductions des erreurs de champ.
String fieldErrorText(AppLocalizations l, FieldError e) => switch (e) {
      FieldError.required => l.errRequired,
      FieldError.invalidEmail => l.errInvalidEmail,
      FieldError.passwordTooShort => l.errPasswordTooShort,
      FieldError.passwordWeak => l.errPasswordWeak,
      FieldError.passwordMismatch => l.errPasswordMismatch,
      FieldError.invalidPhone => l.errInvalidPhone,
      FieldError.invalidOtp => l.errInvalidOtp,
      FieldError.tooLong => l.errTooLong,
      FieldError.invalidTaxId => l.errInvalidTaxId,
      FieldError.invalidNumber => l.errInvalidNumber,
    };

/// Adapte un validateur pur au format attendu par `TextFormField`.
String? Function(String?) fieldValidator(
        BuildContext context, FieldError? Function(String?) rule) =>
    (v) {
      final e = rule(v);
      return e == null ? null : fieldErrorText(context.l10n, e);
    };

/// Message utilisateur pour n'importe quelle erreur d'action.
String failureText(BuildContext context, Object error) {
  final l = context.l10n;
  if (error is ConsentRequired) return l.consentRequired;
  if (error is! AuthFailure) return l.failUnknown;
  return switch (error.code) {
    AuthFailureCode.invalidEmail => l.failInvalidEmail,
    AuthFailureCode.weakPassword => l.failWeakPassword,
    AuthFailureCode.emailInUse => l.failEmailInUse,
    AuthFailureCode.wrongCredentials => l.failWrongCredentials,
    AuthFailureCode.userDisabled => l.failUserDisabled,
    AuthFailureCode.tooManyRequests => l.failTooManyRequests,
    AuthFailureCode.lockedOut => l.failLockedOut(error.lockedUntil == null
        ? '–'
        : DateFormat.Hm(Localizations.localeOf(context).languageCode)
            .format(error.lockedUntil!)),
    AuthFailureCode.invalidPhone => l.failInvalidPhone,
    AuthFailureCode.invalidCode => l.failInvalidCode,
    AuthFailureCode.codeExpired => l.failCodeExpired,
    AuthFailureCode.network => l.failNetwork,
    AuthFailureCode.cancelled => l.failCancelled,
    AuthFailureCode.providerUnavailable => l.failProviderUnavailable,
    AuthFailureCode.requiresRecentLogin => l.failRequiresRecentLogin,
    AuthFailureCode.unknown => l.failUnknown,
  };
}

String roleLabel(AppLocalizations l, UserRole r) => switch (r) {
      UserRole.citizen => l.roleCitizen,
      UserRole.collector => l.roleCollector,
      UserRole.recycler => l.roleRecycler,
      UserRole.admin => l.roleAdmin,
    };

String roleDescription(AppLocalizations l, UserRole r) => switch (r) {
      UserRole.citizen => l.roleCitizenDesc,
      UserRole.collector => l.roleCollectorDesc,
      UserRole.recycler => l.roleRecyclerDesc,
      UserRole.admin => l.roleAdminNotice,
    };

String roleEmoji(UserRole r) => switch (r) {
      UserRole.citizen => '🧑‍🦱',
      UserRole.collector => '🚚',
      UserRole.recycler => '🏭',
      UserRole.admin => '🖥️',
    };
