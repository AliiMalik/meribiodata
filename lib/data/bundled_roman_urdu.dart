import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:meribiodata/domain/text/roman_urdu.dart';

/// [RomanUrduDictionary] backed by `assets/data/roman_urdu.json`.
///
/// A data asset so entries can be added without a release-blocking code change
/// and reviewed by a non-programmer (9.2). Accuracy improves purely by growing
/// this file.
class BundledRomanUrduDictionary implements RomanUrduDictionary {
  const BundledRomanUrduDictionary._(this._entries);

  static const assetPath = 'assets/data/roman_urdu.json';

  /// Normalised Roman token → Urdu spellings, best first.
  final Map<String, List<String>> _entries;

  int get entryCount => _entries.length;

  static Future<BundledRomanUrduDictionary> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final entries = <String, List<String>>{};
    // Sections are organisational only — names, places, words all share one
    // lookup space, because a user typing "Malik" may mean a surname or a
    // word and the answer is the same either way.
    for (final section in json.entries) {
      if (section.value case final Map<String, dynamic> table) {
        for (final entry in table.entries) {
          if (entry.value case final String urdu) {
            entries.putIfAbsent(entry.key, () => <String>[]).add(urdu);
          }
        }
      }
    }

    return BundledRomanUrduDictionary._(entries);
  }

  @override
  List<String> lookup(String token) => _entries[token] ?? const [];
}
