/// Erreurs de validation de formulaires, traduites dans l'UI.
enum FieldError {
  required,
  invalidEmail,
  passwordTooShort,
  passwordWeak,
  passwordMismatch,
  invalidPhone,
  invalidOtp,
  tooLong,
  invalidTaxId,
  invalidNumber,
}

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

FieldError? validateRequired(String? v, {int? maxLength}) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return FieldError.required;
  if (maxLength != null && t.length > maxLength) return FieldError.tooLong;
  return null;
}

FieldError? validateEmail(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return FieldError.required;
  return _email.hasMatch(t) ? null : FieldError.invalidEmail;
}

/// Au moins 8 caractères, dont une lettre et un chiffre.
FieldError? validatePassword(String? v) {
  final t = v ?? '';
  if (t.isEmpty) return FieldError.required;
  if (t.length < 8) return FieldError.passwordTooShort;
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(t);
  final hasDigit = RegExp(r'\d').hasMatch(t);
  return hasLetter && hasDigit ? null : FieldError.passwordWeak;
}

FieldError? validatePasswordConfirmation(String? password, String? confirm) {
  if ((confirm ?? '').isEmpty) return FieldError.required;
  return password == confirm ? null : FieldError.passwordMismatch;
}

/// Normalise un numéro au format E.164. Un numéro local tunisien à
/// 8 chiffres (ex. « 22 123 456 ») devient « +21622123456 ».
/// Retourne `null` si le numéro est invalide.
String? normalizePhone(String? v) {
  var t = (v ?? '').replaceAll(RegExp(r'[\s.\-()]'), '');
  if (t.startsWith('00')) t = '+${t.substring(2)}';
  if (RegExp(r'^[2-9]\d{7}$').hasMatch(t)) return '+216$t';
  if (t.startsWith('+216')) {
    return RegExp(r'^\+216[2-9]\d{7}$').hasMatch(t) ? t : null;
  }
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(t) ? t : null;
}

FieldError? validatePhone(String? v) {
  if ((v ?? '').trim().isEmpty) return FieldError.required;
  return normalizePhone(v) == null ? FieldError.invalidPhone : null;
}

FieldError? validateOtp(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return FieldError.required;
  return RegExp(r'^\d{6}$').hasMatch(t) ? null : FieldError.invalidOtp;
}

/// Matricule fiscal tunisien : 7 chiffres + lettre de contrôle, suivis
/// optionnellement du code TVA, de la catégorie et du n° d'établissement
/// (ex. « 1234567A/A/M/000 »).
FieldError? validateTaxId(String? v) {
  final t = (v ?? '').toUpperCase().replaceAll(' ', '');
  if (t.isEmpty) return FieldError.required;
  final ok = RegExp(r'^\d{7}[A-Z](/?[ABDNP]/?[MPCNE]/?\d{3})?$').hasMatch(t);
  return ok ? null : FieldError.invalidTaxId;
}

FieldError? validatePositiveNumber(String? v) {
  final t = (v ?? '').trim().replaceAll(',', '.');
  if (t.isEmpty) return FieldError.required;
  final n = double.tryParse(t);
  return n != null && n > 0 ? null : FieldError.invalidNumber;
}
