import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:meribiodata/domain/biodata/label_resolver.dart';
import 'package:meribiodata/domain/render/document_builder.dart';

/// [BuiltInLabels] backed by `assets/i18n/field_labels.json`.
///
/// Deliberately a data asset rather than Dart code or an ARB file: adding a
/// document language must not require a code change (§5), and a translator has
/// to be able to review it without reading Dart.
class BundledLabels implements BuiltInLabels {
  const BundledLabels._(
    this._sections,
    this._fields,
    this._options,
    this._strings,
    this._reviewStatus,
  );

  static const assetPath = 'assets/i18n/field_labels.json';

  final Map<String, Map<String, String>> _sections;
  final Map<String, Map<String, String>> _fields;
  final Map<String, Map<String, Map<String, String>>> _options;
  final Map<String, Map<String, String>> _strings;
  final Map<String, String> _reviewStatus;

  static Future<BundledLabels> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return BundledLabels._(
      _table(json['sections']),
      _table(json['fields']),
      _optionTable(json['options']),
      _table(json['documentStrings']),
      _flatTable(json['_reviewStatus']),
    );
  }

  /// The document's own vocabulary — units, age, sibling status — in
  /// [localeCode], falling back to English per key so a partially translated
  /// language still produces a usable document.
  DocumentStrings stringsFor(String localeCode) {
    final table = _strings[localeCode] ?? const {};
    final english = _strings['en'] ?? const {};
    String pick(String key, String fallback) =>
        table[key] ?? english[key] ?? fallback;

    return DocumentStrings(
      years: pick('years', '{n} years'),
      feetInches: pick('feetInches', '{f} ft {i} in'),
      centimetres: pick('centimetres', '{n} cm'),
      kilograms: pick('kilograms', '{n} kg'),
      pounds: pick('pounds', '{n} lb'),
      perMonth: pick('perMonth', 'per month'),
      perYear: pick('perYear', 'per year'),
      married: pick('married', 'married'),
      unmarried: pick('unmarried', 'unmarried'),
      onRequest: pick('onRequest', 'on request'),
      untitled: pick('untitled', 'Biodata'),
    );
  }

  /// Whether a language's document labels have been checked by a native
  /// speaker. Draft languages still render — they just are not signed off.
  bool isReviewed(String localeCode) => _reviewStatus[localeCode] == 'reviewed';

  /// Languages that have any document labels at all.
  Iterable<String> get translatedLanguages =>
      _fields['personal.name']?.keys ?? const [];

  @override
  String? fieldLabel(String builtInKey, String localeCode) =>
      _fields[builtInKey]?[localeCode];

  @override
  String? sectionTitle(String builtInKey, String localeCode) =>
      _sections[builtInKey]?[localeCode];

  /// Translated text for a dropdown option, e.g. `maslak` / `Hanafi`.
  ///
  /// Options are stored by their canonical English value so that changing the
  /// document language re-renders the same answer in the new language rather
  /// than losing it.
  String optionLabel(String group, String value, String localeCode) =>
      _options[group]?[value]?[localeCode] ??
      _options[group]?[value]?['en'] ??
      value;

  /// For nodes whose values are plain strings. Keys starting with `_` are
  /// documentation for whoever edits the asset, not data.
  static Map<String, String> _flatTable(Object? node) {
    if (node is! Map) return const {};
    return {
      for (final entry in node.entries)
        if (!(entry.key as String).startsWith('_') && entry.value is String)
          entry.key as String: entry.value as String,
    };
  }

  static Map<String, Map<String, String>> _table(Object? node) {
    if (node is! Map) return const {};
    return {
      for (final entry in node.entries)
        if (entry.value case final Map<String, dynamic> translations)
          entry.key as String: {
            for (final t in translations.entries) t.key: t.value as String,
          },
    };
  }

  static Map<String, Map<String, Map<String, String>>> _optionTable(
    Object? node,
  ) {
    if (node is! Map) return const {};
    return {
      for (final group in node.entries)
        group.key as String: _table(group.value),
    };
  }
}
