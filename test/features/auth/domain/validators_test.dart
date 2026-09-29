import 'package:ecoflow/features/auth/domain/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('accepts valid addresses', () => expect(validateEmail(' amine@eco.tn '), isNull));
    test('rejects invalid ones', () {
      expect(validateEmail(''), FieldError.required);
      expect(validateEmail('amine@'), FieldError.invalidEmail);
      expect(validateEmail('a b@c.tn'), FieldError.invalidEmail);
    });
  });

  group('password', () {
    test('needs 8 chars with letters and digits', () {
      expect(validatePassword('abc1'), FieldError.passwordTooShort);
      expect(validatePassword('abcdefgh'), FieldError.passwordWeak);
      expect(validatePassword('12345678'), FieldError.passwordWeak);
      expect(validatePassword('recycle26'), isNull);
    });
    test('confirmation must match', () {
      expect(validatePasswordConfirmation('recycle26', 'recycle27'), FieldError.passwordMismatch);
      expect(validatePasswordConfirmation('recycle26', 'recycle26'), isNull);
    });
  });

  group('phone', () {
    test('normalizes Tunisian local numbers', () {
      expect(normalizePhone('22 123 456'), '+21622123456');
      expect(normalizePhone('0021622123456'), '+21622123456');
      expect(normalizePhone('+216 98-765-432'), '+21698765432');
    });
    test('accepts other international numbers', () {
      expect(normalizePhone('+33 6 12 34 56 78'), '+33612345678');
    });
    test('rejects invalid numbers with a clear error', () {
      expect(normalizePhone('12345'), isNull);
      expect(normalizePhone('+216 12 345 678'), isNull);
      expect(validatePhone('abc'), FieldError.invalidPhone);
      expect(validatePhone(''), FieldError.required);
    });
  });

  test('OTP is 6 digits', () {
    expect(validateOtp('12345'), FieldError.invalidOtp);
    expect(validateOtp('12a456'), FieldError.invalidOtp);
    expect(validateOtp('123456'), isNull);
  });

  test('Tunisian tax id', () {
    expect(validateTaxId('1234567A/A/M/000'), isNull);
    expect(validateTaxId('1234567a am 000'), isNull);
    expect(validateTaxId('1234567A'), isNull);
    expect(validateTaxId('123456A'), FieldError.invalidTaxId);
    expect(validateTaxId('1234567A/X/M/000'), FieldError.invalidTaxId);
  });

  test('required and max length', () {
    expect(validateRequired('  '), FieldError.required);
    expect(validateRequired('abcd', maxLength: 3), FieldError.tooLong);
  });

  test('positive number accepts comma decimals', () {
    expect(validatePositiveNumber('12,5'), isNull);
    expect(validatePositiveNumber('0'), FieldError.invalidNumber);
    expect(validatePositiveNumber('x'), FieldError.invalidNumber);
  });
}
