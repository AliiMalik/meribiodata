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
    this.now,
  });

  final BuiltInLabels labels;

  /// Fallback vocabulary when [stringsFor] is not supplied.
  final DocumentStrings strings;

  /// Resolves the document's vocabulary for a locale. Injected rather than
  /// looked up here so this class stays pure Dart and testable without assets.
  final DocumentStrings Function(String localeCode)? stringsFor;

  /// Injectable so age-dependent goldens are stable.
  final DateTime? now;

  RenderedDocument build(
    BiodataProfile profile, {
    ExportMode mode = ExportMode.full,
    String? watermark,
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
  String _isolate(String text, FieldType type, LanguageDescriptor language) {
    if (!language.isRtl) return text;
    return type.needsBidiIsolation || type == FieldType.date
        ? BidiText.isolate(text)
        : BidiText.isolateNumericRuns(text);
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
      final parts = raw
          .split(RegExp('[,\n]'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      return parts.isEmpty ? null : Digits.format(parts.last, digits);
    }

    return null;
  }

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
    if (field.unitPreference == LengthUnit.centimetres.wire) {
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
    if (field.unitPreference == MassUnit.pounds.wire) {
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
