// The alphabet strings below are data, not prose. Wrapping them would make a
// missing letter much harder to spot in review.
// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:pdf/pdf.dart';

/// §4 asks for a coverage test that fails if any character of a supported
/// language renders as `.notdef` (tofu).
///
/// Rather than rendering and eyeballing, this inspects the shipped font files
/// directly: every codepoint a language needs must map to a real glyph in that
/// language's font, or in its declared fallback. Tofu then becomes impossible
/// by construction rather than something a reviewer has to spot.
void main() {
  var coverage = <String, Set<int>>{};

  Set<int> glyphsIn(String path) {
    final bytes = File(path).readAsBytesSync();
    final parser = TtfParser(ByteData.view(Uint8List.fromList(bytes).buffer));
    return parser.charToGlyphIndexMap.entries
        .where((e) => e.value != 0)
        .map((e) => e.key)
        .toSet();
  }

  setUpAll(() {
    coverage = {
      'NotoNastaliqUrdu': glyphsIn(
        'assets/fonts/NotoNastaliqUrdu-Regular.ttf',
      ),
      'NotoNaskhArabic': glyphsIn('assets/fonts/NotoNaskhArabic-Regular.ttf'),
      'Inter': glyphsIn('assets/fonts/Inter-Regular.ttf'),
    };
  });

  /// The letters each language actually needs. Sindhi and Pashto carry the
  /// extended letters the build prompt calls out by name.
  const alphabets = <String, String>{
    'ur':
        'ا آ ب پ ت ٹ ث ج چ ح خ د ڈ ذ ر ڑ ز ژ س ش ص ض ط ظ ع غ ف ق ک گ ل م ن ں و ہ ھ ء ی ے',
    'sd':
        'ا ب ٻ ڀ ت ٿ ٽ ٺ ث پ ج ڄ ڃ چ ڇ ح خ د ڌ ڏ ڊ ڍ ذ ر ڙ ز س ش ص ض ط ظ ع غ ف ڦ ق ڪ ک گ ڳ ڱ ل م ن ڻ ه ھ و ي ۽ ۾ ء',
    'ps':
        'ا ب پ ت ټ ث ج ځ چ څ ح خ د ډ ذ ر ړ ز ژ ږ س ش ښ ص ض ط ظ ع غ ف ق ک ګ ل م ن ڼ و ه ی ې ۍ ئ',
    'pa_Arab':
        'ا ب بھ پ ت ٹ ث ج چ ح خ د ڈ ذ ر ڑ ز ژ س ش ص ض ط ظ ع غ ف ق ک گ ل ل م ن ݨ و ہ ھ ی ے',
    'en': 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789',
  };

  /// Codepoints every document needs regardless of language.
  const shared = '0123456789 .,/()-+:';

  for (final entry in alphabets.entries) {
    test('${entry.key}: every letter has a glyph', () {
      final language = AppLanguages.byCode(entry.key);
      final fonts = [
        language.documentFontFamily,
        ...language.documentFontFallback,
      ];
      final available = <int>{
        for (final font in fonts) ...?coverage[font],
      };

      final missing = <String>[];
      for (final rune in entry.value.runes) {
        if (rune == 0x20) continue;
        if (!available.contains(rune)) {
          missing.add(
            '${String.fromCharCode(rune)} '
            '(U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')})',
          );
        }
      }

      expect(
        missing,
        isEmpty,
        reason:
            'These characters would render as tofu in ${language.englishName}, '
            'using ${fonts.join(' → ')}: ${missing.join(', ')}',
      );
    });
  }

  test('every language can print digits, dates and phone numbers', () {
    // Asserted against each language's whole fallback chain, not against fonts
    // in isolation: Noto Naskh Arabic genuinely lacks `/ ( ) - +`, so Sindhi
    // and Pashto depend on Inter being in the chain. Drop it and a phone
    // number silently renders in a system font.
    for (final language in AppLanguages.documentLanguages) {
      final fonts = [
        language.documentFontFamily,
        ...language.documentFontFallback,
      ];
      final available = <int>{
        for (final font in fonts) ...?coverage[font],
      };

      final missing = shared.runes
          .where((r) => r != 0x20 && !available.contains(r))
          .map(String.fromCharCode)
          .toList();

      expect(
        missing,
        isEmpty,
        reason:
            '${language.englishName} (${fonts.join(' → ')}) cannot print: '
            '$missing',
      );
    }
  });

  test('Eastern Arabic numerals are covered where they are the default', () {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const arabic = AppLanguages.arabic;
    final available = <int>{
      ...?coverage[arabic.documentFontFamily],
      for (final f in arabic.documentFontFallback) ...?coverage[f],
    };

    expect(
      eastern.runes.where((r) => !available.contains(r)),
      isEmpty,
      reason: 'Arabic defaults to Eastern digits, so they must have glyphs.',
    );
  });

  test('the Sindhi postposition U+06FE has a glyph', () {
    // Flagged as uncertain in the M0 report; pinned here so it cannot regress
    // silently.
    const sindhi = AppLanguages.sindhi;
    final available = <int>{
      ...?coverage[sindhi.documentFontFamily],
      for (final f in sindhi.documentFontFallback) ...?coverage[f],
    };

    expect(available, contains(0x06FE));
  });
}
