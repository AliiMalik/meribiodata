import 'dart:typed_data';

import 'package:meribiodata/domain/biodata/biodata_profile.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/field_descriptor.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/field_values.dart';
import 'package:meribiodata/domain/biodata/label_resolver.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/text/bidi_text.dart';
import 'package:meribiodata/domain/text/digits.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

/// Translated strings the *document* needs, as distinct from the app UI.
///
/// Supplied by the caller so this stays pure Dart and golden tests can pin
/// exact output.
class DocumentStrings {
  const DocumentStrings({
    required this.years,
    required this.feetInches,
    required this.centimetres,
    required this.kilograms,
    required this.pounds,
    required this.perMonth,
    required this.perYear,
    required this.married,
    required this.unmarried,
    required this.onRequest,
    required this.untitled,
  });

  /// e.g. `'{n} years'`. `{n}` is substituted.
  final String years;

  /// e.g. `"{f} ft {i} in"`.
  final String feetInches;
  final String centimetres;
  final String kilograms;
  final String pounds;
  final String perMonth;
  final String perYear;
  final String married;
  final String unmarried;

  /// Placeholder used by Shareable mode (9.4).
  final String onRequest;

  final String untitled;

  static const english = DocumentStrings(
    years: '{n} years',
    feetInches: '{f} ft {i} in',
    centimetres: '{n} cm',
    kilograms: '{n} kg',
    pounds: '{n} lb',
    perMonth: 'per month',
    perYear: 'per year',
    married: 'married',
    unmarried: 'unmarried',
    onRequest: 'on request',
    untitled: 'Biodata',
  );
}

/// How height and weight are written, when the field itself does not say.
///
/// A field may pin its own unit, which wins. Everything else follows this,
/// which comes from the app's Settings — so changing the setting restyles every
/// biodata that never overrode it, without rewriting a single stored value.
/// Values are always stored canonically (see [LengthUnit]); this is display
/// only.
class DocumentUnits {
  const DocumentUnits({
    this.length = LengthUnit.feetInches,
    this.mass = MassUnit.kilograms,
  });

  final LengthUnit length;
  final MassUnit mass;

  static const standard = DocumentUnits();
}

/// Turns a stored profile into something a template can lay out.
///
/// This is where every "how should that look" decision lives — units, dates,
/// digits, sibling shorthand, bidi isolation, and Shareable-mode masking — so
/// that templates only decide *where things go*, and four templates cannot
/// disagree about how a height is written.
class DocumentBuilder {
  const DocumentBuilder({
    required this.labels,
    this.strings = DocumentStrings.english,
    this.stringsFor,
    this.units = DocumentUnits.standard,
    this.now,
  });

  final BuiltInLabels labels;

  /// Fallback vocabulary when [stringsFor] is not supplied.
  final DocumentStrings strings;

  /// Resolves the document's vocabulary for a locale. Injected rather than
  /// looked up here so this class stays pure Dart and testable without assets.
  final DocumentStrings Function(String localeCode)? stringsFor;

  /// Fallback units for fields that do not pin one of their own.
  final DocumentUnits units;

  /// Injectable so age-dependent goldens are stable.
  final DateTime? now;

  /// [photo] is supplied by the caller rather than read from
  /// [BiodataProfile.photoPath], for two reasons: this class stays pure Dart
  /// with no filesystem, and the include-or-not decision (9.3) lives in one
  /// place in the UI instead of being re-derived here.
  RenderedDocument build(
    BiodataProfile profile, {
    ExportMode mode = ExportMode.full,
    String? watermark,
    Uint8List? photo,
  }) {
    final language = AppLanguages.byCode(profile.documentLanguageCode);
    final resolver = LabelResolver(labels);
    final digits = language.defaultDigits;
    final words = stringsFor?.call(language.code) ?? strings;

    final sections = <RenderedSection>[];
    for (final section in profile.schema.visibleSections) {
      final fields = <RenderedField>[];

      for (final field in profile.schema.visibleFieldsIn(section.id)) {
        final rendered = _field(
          field: field,
          profile: profile,
          language: language,
          digits: digits,
          mode: mode,
          words: words,
        );
        // A field with no answer simply does not print. A biodata full of
        // empty rows reads as unfinished.
        if (rendered != null) fields.add(rendered);
      }

      sections.add(
        RenderedSection(
          title: resolver.sectionTitle(section, language.code),
          fields: fields,
        ),
      );
    }

    return RenderedDocument(
      title: _title(profile, words),
      sections: sections,
      language: language,
      digitStyle: digits,
      mode: mode,
      headerText: profile.headerText,
      watermark: watermark,
      photo: photo,
      photoOnSeparatePage: profile.photoOnSeparatePage,
    );
  }

  String _title(BiodataProfile profile, DocumentStrings words) {
    final nameField = profile.schema.fieldByBuiltInKey(BuiltInKeys.name);
    final value = nameField == null ? null : profile.values[nameField.id];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return words.untitled;
  }

  RenderedField? _field({
    required FieldDescriptor field,
    required BiodataProfile profile,
    required LanguageDescriptor language,
    required DigitStyle digits,
    required ExportMode mode,
    required DocumentStrings words,
  }) {
    final raw = profile.values[field.id];
    final resolver = LabelResolver(labels);
    final label = resolver.fieldLabel(field, language.code);

    final masking = mode == ExportMode.shareable && field.isSensitive;
    if (masking && field.masking == MaskingStrategy.omit) return null;

    var text = _format(field, raw, digits, words);
    var wasMasked = false;

    if (masking && text != null) {
      switch (field.masking) {
        case MaskingStrategy.generalise:
          text = _generalise(field, raw, digits, words) ?? text;
        case MaskingStrategy.placeholder:
          text = words.onRequest;
        case MaskingStrategy.omit:
          return null;
      }
      wasMasked = true;
    }

    if (text == null || text.isEmpty) return null;

    return RenderedField(
      id: field.id,
      label: label,
      value: _isolate(text, field.type, language),
      type: field.type,
      isSensitive: field.isSensitive,
      wasMasked: wasMasked,
    );
  }

  /// Numbers are isolated so multi-group values do not reverse in an RTL
  /// document; free text has only its numeric runs isolated, so an Urdu
  /// sentence stays a single right-to-left flow.
  ///
  /// The decision is made on the **formatted string**, not on the field type,
  /// and that distinction is the whole point. By the time a value reaches here
  /// its localised unit words have already been substituted in: a height is not
  /// `6 1` but `6 فٹ 1 انچ`. Wrapping that in a left-to-right isolate — which
  /// is exactly right for `+92 300 1234567` — lays its runs out left to right
  /// and reverses the word/number pairs, so 6 feet 1 inch reads back as 1 foot
  /// 6 inches.
  ///
  /// Height showed it first because it is the only value with *two* number-word
  /// pairs. Weight, currency and dates carried the same flaw invisibly, having
  /// only one number for the reversal to act on.
  String _isolate(String text, FieldType type, LanguageDescriptor language) {
    if (!language.isRtl) return text;

    final numericType = type.needsBidiIsolation || type == FieldType.date;
    if (numericType && !BidiText.hasStrongRtl(text)) {
      // A bare number or date: force the whole run left-to-right.
      return BidiText.isolate(text);
    }
    // Prose, or a number that now carries RTL words. Isolate the digit groups
    // and let the bidi algorithm order the rest, which it does correctly.
    return BidiText.isolateNumericRuns(text);
  }

  String? _format(
    FieldDescriptor field,
    Object? raw,
    DigitStyle digits,
    DocumentStrings words,
  ) {
    if (raw == null) return null;
    final text = switch (field.type) {
      FieldType.date => _date(field, raw, words),
      FieldType.height => _height(field, raw, words),
      FieldType.weight => _weight(field, raw, words),
      FieldType.currency => _currency(raw, words),
      FieldType.repeatableGroup => _group(field, raw, words),
      FieldType.boolean => raw == true ? words.married : null,
      _ => raw.toString().trim(),
    };
    if (text == null || text.isEmpty) return null;
    return Digits.format(text, digits);
  }

  /// Shareable-mode coarsening (9.4): an address becomes its last line, a date
  /// of birth becomes an age. Generalising beats omitting — a visible gap
  /// invites questions, "Lahore" just reads as discretion.
  String? _generalise(
    FieldDescriptor field,
    Object? raw,
    DigitStyle digits,
    DocumentStrings words,
  ) {
    if (raw == null) return null;

    if (field.type == FieldType.date && raw is String) {
      final date = DateTime.tryParse(raw);
      if (date == null) return null;
      return Digits.format(_years(date, words), digits);
    }

    if (field.type == FieldType.multiline && raw is String) {
      // The last comma-separated part of an address is the city often enough
      // to be a sensible default, and the user can always edit the field.
      //
      // The separator list includes U+060C ARABIC COMMA and U+061B ARABIC
      // SEMICOLON. Splitting on the ASCII comma alone silently failed for
      // every Urdu, Sindhi and Pashto address — which is to say, for exactly
      // the users this masking exists to protect. Caught by a golden.
      final parts = raw
          .split(_addressSeparators)
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      return parts.isEmpty ? null : Digits.format(parts.last, digits);
    }

    return null;
  }

  /// Address separators, including U+060C ARABIC COMMA and U+061B ARABIC
  /// SEMICOLON — the ones Urdu, Sindhi and Pashto addresses actually use.
  static final RegExp _addressSeparators = RegExp('[,،؛\n]');

  String _years(DateTime date, DocumentStrings words) =>
      words.years.replaceAll('{n}', '${ageOn(date, now ?? DateTime.now())}');

  String? _date(FieldDescriptor field, Object raw, DocumentStrings words) {
    if (raw is! String) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return null;

    final formatted = '${date.day}/${date.month}/${date.year}';
    return switch (field.dateDisplay ?? DateDisplay.dateOnly) {
      DateDisplay.dateOnly => formatted,
      DateDisplay.ageOnly => _years(date, words),
      DateDisplay.dateAndAge => '$formatted (${_years(date, words)})',
    };
  }

  String? _height(
    FieldDescriptor field,
    Object raw,
    DocumentStrings words,
  ) {
    if (raw is! Map<String, dynamic>) return null;
    final height = HeightValue.fromJson(raw);
    final unit = field.unitPreference ?? units.length.wire;
    if (unit == LengthUnit.centimetres.wire) {
      return words.centimetres.replaceAll(
        '{n}',
        '${height.centimetres.round()}',
      );
    }
    return words.feetInches
        .replaceAll('{f}', '${height.feet}')
        .replaceAll('{i}', '${height.inches}');
  }

  String? _weight(
    FieldDescriptor field,
    Object raw,
    DocumentStrings words,
  ) {
    if (raw is! Map<String, dynamic>) return null;
    final weight = WeightValue.fromJson(raw);
    final unit = field.unitPreference ?? units.mass.wire;
    if (unit == MassUnit.pounds.wire) {
      return words.pounds.replaceAll('{n}', '${weight.pounds.round()}');
    }
    return words.kilograms.replaceAll('{n}', '${weight.kilograms.round()}');
  }

  String? _currency(Object raw, DocumentStrings words) {
    if (raw is! Map<String, dynamic>) return null;
    final money = CurrencyValue.fromJson(raw);
    final period = money.period == IncomePeriod.perMonth
        ? words.perMonth
        : words.perYear;
    return '${money.currencyCode} ${money.amount} $period';
  }

  /// Renders the shorthand families actually write — "2 (1 married)" — and
  /// only lists people when the user filled them in (§6.2).
  String? _group(
    FieldDescriptor field,
    Object raw,
    DocumentStrings words,
  ) {
    if (raw is! Map<String, dynamic>) return null;
    final group = RepeatableGroupValue.fromJson(raw);
    if (group.isEmpty) return null;

    final summary = StringBuffer('${group.effectiveTotal}');
    if (group.marriedCount case final int married when married > 0) {
      summary.write(' ($married ${words.married})');
    }

    if (!group.hasDetail) return summary.toString();

    final people = <String>[];
    for (final entry in group.entries) {
      final parts = <String>[];
      for (final inner in field.groupFields) {
        final value = entry[inner.id];
        if (value is String && value.trim().isNotEmpty) {
          parts.add(value.trim());
        }
      }
      if (parts.isNotEmpty) people.add(parts.join(' — '));
    }
    if (people.isEmpty) return summary.toString();

    return '$summary\n${people.join('\n')}';
  }
}
