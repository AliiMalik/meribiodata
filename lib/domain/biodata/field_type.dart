import 'package:json_annotation/json_annotation.dart';

/// The kinds of field the form engine can render.
///
/// `@JsonValue` is explicit on every constant because these names are written
/// to disk and to `.mbd` backup files (9.5). Renaming a Dart constant must
/// never change the stored representation.
@JsonEnum(valueField: 'wire')
enum FieldType {
  text('text'),
  multiline('multiline'),
  number('number'),
  date('date'),
  dropdown('dropdown'),
  boolean('boolean'),
  height('height'),
  weight('weight'),
  currency('currency'),
  repeatableGroup('repeatableGroup');

  const FieldType(this.wire);

  final String wire;

  /// Whether a value of this type is stored as a structured object rather than
  /// a scalar. Drives serialization and the Shareable-mode masking rules (9.4).
  bool get isStructured => switch (this) {
    FieldType.height ||
    FieldType.weight ||
    FieldType.currency ||
    FieldType.repeatableGroup => true,
    _ => false,
  };

  /// Whether rendered values need Unicode isolate marks in an RTL document.
  ///
  /// M0 finding: `+92 300 1234567` renders as `1234567 300 92+` inside an Urdu
  /// paragraph. That is correct Unicode bidi — the spaces are neutral and take
  /// the paragraph direction — so the fix belongs to the *field type*, not to
  /// any one template. See `docs/spike-nastaliq.md`.
  bool get needsBidiIsolation => switch (this) {
    FieldType.number ||
    FieldType.currency ||
    FieldType.height ||
    FieldType.weight => true,
    // Free text can contain a phone number too, so isolation is applied to
    // detected runs rather than the whole value — see BidiText.
    _ => false,
  };
}

/// How a sensitive field behaves in a Shareable export (9.4).
///
/// Carried on every field from M2 so the export modes in M5 do not require a
/// stored-schema migration. Nothing reads it before M5.
@JsonEnum(valueField: 'wire')
enum MaskingStrategy {
  /// Drop the row entirely. Right for values with no useful coarse form.
  omit('omit'),

  /// Show a coarser version: an address becomes its city, a date of birth
  /// becomes an age. Usually better than omission — a visible gap invites
  /// questions, whereas "Lahore" just reads as normal discretion.
  generalise('generalise'),

  /// Keep the row, replace the value: "Contact: on request".
  placeholder('placeholder');

  const MaskingStrategy(this.wire);

  final String wire;
}

/// How a date field is presented in the document (§6.2, Date of Birth).
@JsonEnum(valueField: 'wire')
enum DateDisplay {
  dateOnly('dateOnly'),
  ageOnly('ageOnly'),
  dateAndAge('dateAndAge');

  const DateDisplay(this.wire);

  final String wire;
}

/// Canonical storage units. Values are always stored in the canonical unit and
/// converted for display, so changing the display preference never rewrites
/// data and never loses precision.
@JsonEnum(valueField: 'wire')
enum LengthUnit {
  centimetres('cm'),
  feetInches('ftIn');

  const LengthUnit(this.wire);

  final String wire;
}

@JsonEnum(valueField: 'wire')
enum MassUnit {
  kilograms('kg'),
  pounds('lb');

  const MassUnit(this.wire);

  final String wire;
}

@JsonEnum(valueField: 'wire')
enum IncomePeriod {
  perMonth('month'),
  perYear('year');

  const IncomePeriod(this.wire);

  final String wire;
}
