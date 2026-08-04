import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';

part 'field_values.freezed.dart';
part 'field_values.g.dart';

/// Height, stored canonically in centimetres.
///
/// Storing one canonical unit means toggling ft/in ↔ cm is a display change
/// that never rewrites data and never accumulates rounding error.
@freezed
abstract class HeightValue with _$HeightValue {
  const factory HeightValue({required double centimetres}) = _HeightValue;

  const HeightValue._();

  factory HeightValue.fromJson(Map<String, dynamic> json) =>
      _$HeightValueFromJson(json);

  factory HeightValue.fromFeetInches(int feet, int inches) =>
      HeightValue(centimetres: (feet * 12 + inches) * 2.54);

  int get feet => (centimetres / 2.54 / 12).floor();

  int get inches => (centimetres / 2.54).round() % 12;

  bool get isPlausible => centimetres >= 100 && centimetres <= 250;
}

/// Weight, stored canonically in kilograms.
@freezed
abstract class WeightValue with _$WeightValue {
  const factory WeightValue({required double kilograms}) = _WeightValue;

  const WeightValue._();

  factory WeightValue.fromJson(Map<String, dynamic> json) =>
      _$WeightValueFromJson(json);

  factory WeightValue.fromPounds(double pounds) =>
      WeightValue(kilograms: pounds * 0.45359237);

  double get pounds => kilograms / 0.45359237;

  bool get isPlausible => kilograms >= 25 && kilograms <= 250;
}

/// An amount of money with its currency and period (§6.2, Income).
@freezed
abstract class CurrencyValue with _$CurrencyValue {
  const factory CurrencyValue({
    required num amount,
    @Default('PKR') String currencyCode,
    @Default(IncomePeriod.perMonth) IncomePeriod period,
  }) = _CurrencyValue;

  const CurrencyValue._();

  factory CurrencyValue.fromJson(Map<String, dynamic> json) =>
      _$CurrencyValueFromJson(json);
}

/// Siblings and similar repeating groups (§6.2, Brothers/Sisters).
///
/// Supports both shapes families actually use: the shorthand "2 brothers,
/// 1 married" via [total] and [marriedCount], and full per-person detail via
/// [entries]. Neither forces the other — a user who only wants to write
/// "2 brothers" must not be made to fill in two names.
@freezed
abstract class RepeatableGroupValue with _$RepeatableGroupValue {
  const factory RepeatableGroupValue({
    int? total,
    int? marriedCount,

    /// One map per person, keyed by the group's inner field ids.
    @Default(<Map<String, dynamic>>[]) List<Map<String, dynamic>> entries,
  }) = _RepeatableGroupValue;

  const RepeatableGroupValue._();

  factory RepeatableGroupValue.fromJson(Map<String, dynamic> json) =>
      _$RepeatableGroupValueFromJson(json);

  /// The user filled in individual people rather than only a count.
  bool get hasDetail => entries.isNotEmpty;

  /// Effective count: explicit total if given, otherwise the number of
  /// detailed entries.
  int get effectiveTotal => total ?? entries.length;

  bool get isEmpty => total == null && entries.isEmpty;
}

/// Derives an age from a date of birth (§6.2 — "auto-computes age").
int ageOn(DateTime birthDate, DateTime asOf) {
  var age = asOf.year - birthDate.year;
  final hadBirthdayThisYear =
      asOf.month > birthDate.month ||
      (asOf.month == birthDate.month && asOf.day >= birthDate.day);
  if (!hadBirthdayThisYear) age--;
  return age;
}
