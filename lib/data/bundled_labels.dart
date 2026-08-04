import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:meribiodata/domain/biodata/label_resolver.dart';

/// [BuiltInLabels] backed by `assets/i18n/field_labels.json`.
///
/// Deliberately a data asset rather than Dart code or an ARB file: adding a
/// document language must not require a code change (§5), and a translator has
/// to be able to review it without reading Dart.
class BundledLabels implements BuiltInLabels {
  const BundledLabels._(this._sections, this._fields, this._options);

  static const assetPath = 'assets/i18n/field_labels.json';

  final Map<String, Map<String, String>> _sections;
  final Map<String, Map<String, String>> _fields;
  final Map<String, Map<String, Map<String, String>>> _options;

  static Future<BundledLabels> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return BundledLabels._(
      _table(json['sections']),
      _table(json['fields']),
      _optionTable(json['options']),
    );
  }

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
