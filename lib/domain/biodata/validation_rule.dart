import 'package:freezed_annotation/freezed_annotation.dart';

part 'validation_rule.freezed.dart';
part 'validation_rule.g.dart';

/// Why a value was rejected. The UI maps this to a localized message — the
/// domain never produces user-facing English.
enum ValidationError {
  required,
  tooShort,
  tooLong,
  notANumber,
  belowMinimum,
  aboveMaximum,
  badPhoneNumber,
  badDate,
  dateInFuture,
  implausibleDate,
}

/// Declarative validation attached to a `FieldDescriptor`.
///
/// Deliberately data rather than code: a user-created field has to be able to
/// carry validation too, and the whole descriptor is serialized into backups.
@freezed
abstract class ValidationRule with _$ValidationRule {
  const factory ValidationRule({
    int? minLength,
    int? maxLength,
    num? min,
    num? max,
    @Default(false) bool isPhoneNumber,
    @Default(false) bool disallowFutureDates,
  }) = _ValidationRule;

  const ValidationRule._();

  factory ValidationRule.fromJson(Map<String, dynamic> json) =>
      _$ValidationRuleFromJson(json);

  /// Phone numbers, with a Pakistani default. Deliberately permissive about
  /// formatting — families write numbers in many shapes, and rejecting a real
  /// number is worse than accepting an oddly formatted one.
  static const phone = ValidationRule(isPhoneNumber: true, maxLength: 32);

  static const name = ValidationRule(minLength: 1, maxLength: 120);

  static const shortText = ValidationRule(maxLength: 120);

  static const longText = ValidationRule(maxLength: 2000);

  static const pastDate = ValidationRule(disallowFutureDates: true);
}

/// Field-type-agnostic validation of an already-normalized value.
abstract final class Validator {
  /// A phone number is at least 7 digits, at most 15 (E.164), and contains
  /// nothing but digits, spaces, and the usual separators.
  static final _phoneShape = RegExp(r'^[+()\-\s.0-9]+$');

  static ValidationError? validate({
    required Object? value,
    required bool isRequired,
    ValidationRule? rule,
  }) {
    final isEmpty = value == null || (value is String && value.trim().isEmpty);

    if (isEmpty) return isRequired ? ValidationError.required : null;
    if (rule == null) return null;

    if (value is String) {
      final text = value.trim();
      if (rule.minLength case final int min when text.codePointLength < min) {
        return ValidationError.tooShort;
      }
      if (rule.maxLength case final int max when text.codePointLength > max) {
        return ValidationError.tooLong;
      }
      if (rule.isPhoneNumber) return _validatePhone(text);
    }

    if (value is num) {
      if (rule.min case final num min when value < min) {
        return ValidationError.belowMinimum;
      }
      if (rule.max case final num max when value > max) {
        return ValidationError.aboveMaximum;
      }
    }

    if (value is DateTime) return _validateDate(value, rule);

    return null;
  }

  static ValidationError? _validatePhone(String text) {
    if (!_phoneShape.hasMatch(text)) return ValidationError.badPhoneNumber;
    final digits = text.replaceAll(RegExp('[^0-9]'), '').length;
    if (digits < 7 || digits > 15) return ValidationError.badPhoneNumber;
    return null;
  }

  static ValidationError? _validateDate(DateTime value, ValidationRule rule) {
    final now = DateTime.now();
    if (rule.disallowFutureDates && value.isAfter(now)) {
      return ValidationError.dateInFuture;
    }
    // A biodata is for a marriage candidate; a date of birth in 1850 is a
    // typo, not a fact.
    if (value.year < 1900) return ValidationError.implausibleDate;
    return null;
  }
}

extension on String {
  /// Length in code points rather than UTF-16 code units, so a length limit
  /// means roughly the same thing in Urdu as it does in English.
  int get codePointLength => runes.length;
}
