import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

void main() {
  group('registry integrity', () {
    test('language codes are unique', () {
      final codes = AppLanguages.all.map((l) => l.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('every language covers the §5 target list', () {
      expect(AppLanguages.all.length, 12);
      expect(
        AppLanguages.all.map((l) => l.code),
        containsAll(<String>[
          'en',
          'ur',
          'ur_Latn',
          'sd',
          'ps',
          'pa_Arab',
          'skr',
          'bal',
          'hno',
          'brh',
          'ks',
          'ar',
        ]),
      );
    });

    test('byCode falls back to English rather than throwing', () {
      expect(AppLanguages.byCode('zz').code, 'en');
    });
  });

  group('script drives direction, font and pipeline', () {
    test('Latin is LTR and renders via the vector pipeline', () {
      for (final language in AppLanguages.all.where(
        (l) => l.script == TextScript.latin,
      )) {
        expect(language.direction, TextDirection.ltr, reason: language.code);
        expect(
          language.pipeline,
          RenderPipeline.vector,
          reason: language.code,
        );
      }
    });

    test('every Perso-Arabic language is RTL and rasterised (D1)', () {
      for (final language in AppLanguages.all.where(
        (l) => l.script != TextScript.latin,
      )) {
        expect(language.isRtl, isTrue, reason: language.code);
        expect(
          language.pipeline,
          RenderPipeline.raster,
          reason:
              '${language.code}: Pipeline A is unusable for '
              'Perso-Arabic — see docs/spike-nastaliq.md',
        );
      }
    });

    test('Nastaliq gets its measured line-height and a Naskh fallback', () {
      const urdu = AppLanguages.urdu;
      expect(urdu.script, TextScript.nastaliq);
      expect(urdu.lineHeight, greaterThanOrEqualTo(1.9));
      expect(urdu.lineHeight, lessThanOrEqualTo(2.2));
      expect(urdu.documentFontFamily, 'NotoNastaliqUrdu');
      expect(urdu.documentFontFallback, contains('NotoNaskhArabic'));
    });
  });

  group('UI locale vs document language are separate concerns (§5)', () {
    test('Roman Urdu is a UI locale only, never a document language', () {
      expect(AppLanguages.romanUrdu.availableAsDocumentLanguage, isFalse);
      expect(
        AppLanguages.documentLanguages,
        isNot(contains(AppLanguages.romanUrdu)),
      );
    });

    test(
      'only languages with a reviewed ARB file are offered as UI locales',
      () {
        for (final language in AppLanguages.uiLocales) {
          expect(language.hasUiTranslation, isTrue, reason: language.code);
        }
        // M1 ships English and Urdu. This number rises with each ARB file that
        // clears native review (docs/decisions.md D3).
        expect(AppLanguages.uiLocales.length, 2);
      },
    );
  });
}
