import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every shipped locale must define every key in the template.
///
/// `gen_l10n` only warns about gaps; a missing key silently falls back to
/// English at runtime, which is exactly the "half-translated app" that
/// undermines the "made for us" positioning (§5).
void main() {
  final arbDir = Directory('lib/l10n/arb');

  Map<String, dynamic> load(String file) =>
      jsonDecode(File('${arbDir.path}/$file').readAsStringSync())
          as Map<String, dynamic>;

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('arb directory is where l10n.yaml says it is', () {
    expect(arbDir.existsSync(), isTrue);
  });

  test('every locale defines every template key', () {
    final template = messageKeys(load('app_en.arb'));
    expect(template, isNotEmpty);

    final locales = arbDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.endsWith('.arb') && name != 'app_en.arb');

    expect(locales, isNotEmpty, reason: 'expected at least app_ur.arb');

    for (final file in locales) {
      final keys = messageKeys(load(file));
      expect(
        template.difference(keys),
        isEmpty,
        reason: '$file is missing keys present in app_en.arb',
      );
      expect(
        keys.difference(template),
        isEmpty,
        reason: '$file defines keys that no longer exist in app_en.arb',
      );
    }
  });

  test('no message is left as its English source in a translated locale', () {
    final english = load('app_en.arb');
    final urdu = load('app_ur.arb');

    // Deliberate exceptions: the product name, the digit samples and the
    // paper-size names are the same string in every language.
    const sameInEveryLanguage = {
      'appName',
      'settingsDigitWestern',
      'settingsDigitEastern',
      'exportPageA4',
      'exportPageLetter',
    };

    for (final key in messageKeys(urdu)) {
      if (sameInEveryLanguage.contains(key)) continue;
      expect(
        urdu[key],
        isNot(equals(english[key])),
        reason: '"$key" in app_ur.arb is still the English string',
      );
    }
  });
}
