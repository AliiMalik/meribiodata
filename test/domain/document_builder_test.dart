import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/domain/biodata/biodata_profile.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/field_values.dart';
import 'package:meribiodata/domain/biodata/schema_editor.dart';
import 'package:meribiodata/domain/render/document_builder.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/text/bidi_text.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

import '../support/schema_fixtures.dart';

void main() {
  final builder = DocumentBuilder(
    labels: FakeBuiltInLabels.standard,
    now: DateTime.utc(2026, 8, 4),
  );

  BiodataProfile profileWith(
    Map<String, Object> byBuiltInKey, {
    String language = 'en',
  }) {
    final profile = buildTestProfile(documentLanguageCode: language);
    return profile.copyWith(
      values: {
        for (final entry in byBuiltInKey.entries)
          profile.schema.fieldByBuiltInKey(entry.key)!.id: entry.value,
      },
    );
  }

  /// Looks a field up by its built-in key rather than its label — labels
  /// depend on which translations the fake happens to carry, ids do not.
  String valueOf(
    RenderedDocument doc,
    BiodataProfile profile,
    String builtInKey,
  ) {
    final id = profile.schema.fieldByBuiltInKey(builtInKey)!.id;
    return doc.sections
        .expand((s) => s.fields)
        .firstWhere((f) => f.id == id)
        .value;
  }

  group('what prints and what does not', () {
    test('a field with no answer does not print an empty row', () {
      final doc = builder.build(profileWith({BuiltInKeys.name: 'Ali'}));

      expect(doc.fieldCount, 1);
      expect(doc.nonEmptySections.length, 1);
    });

    test('a hidden field is excluded even when it has an answer', () {
      var profile = profileWith({
        BuiltInKeys.name: 'Ali',
        BuiltInKeys.caste: 'Arain',
      });
      final casteId = profile.schema.fieldByBuiltInKey(BuiltInKeys.caste)!.id;
      profile = profile.copyWith(
        schema: profile.schema.setFieldVisible(casteId, isVisible: false),
      );

      expect(builder.build(profile).fieldCount, 1);
    });

    test('a hidden section takes its fields with it', () {
      var profile = profileWith({
        BuiltInKeys.name: 'Ali',
        BuiltInKeys.fatherName: 'Aslam',
      });
      final family = profile.schema.sections.firstWhere(
        (s) => s.builtInKey == BuiltInKeys.family,
      );
      profile = profile.copyWith(
        schema: profile.schema.setSectionVisible(family.id, isVisible: false),
      );

      final doc = builder.build(profile);

      expect(doc.fieldCount, 1);
      expect(doc.sections.length, profile.schema.visibleSections.length);
    });

    test('the title falls back when the name is empty', () {
      expect(builder.build(profileWith({})).title, 'Biodata');
    });

    test('the title is the candidate name when there is one', () {
      expect(
        builder.build(profileWith({BuiltInKeys.name: 'Ali'})).title,
        'Ali',
      );
    });
  });

  group('value formatting', () {
    test('height renders in the unit the field prefers', () {
      final profile = profileWith({
        BuiltInKeys.height: HeightValue.fromFeetInches(5, 9).toJson(),
      });

      expect(
        valueOf(builder.build(profile), profile, BuiltInKeys.height),
        '5 ft 9 in',
      );
    });

    test('weight renders in kilograms by default', () {
      final profile = profileWith({
        BuiltInKeys.weight: const WeightValue(kilograms: 70).toJson(),
      });

      expect(
        valueOf(builder.build(profile), profile, BuiltInKeys.weight),
        '70 kg',
      );
    });

    test('a date shows date and derived age together by default', () {
      final profile = profileWith({
        BuiltInKeys.dob: DateTime(1995, 3, 15).toIso8601String(),
      });

      expect(
        BidiText.strip(
          valueOf(builder.build(profile), profile, BuiltInKeys.dob),
        ),
        '15/3/1995 (31 years)',
      );
    });

    test('currency carries amount, code and period', () {
      final profile = profileWith({
        BuiltInKeys.income: const CurrencyValue(amount: 150000).toJson(),
      });

      expect(
        BidiText.strip(
          valueOf(builder.build(profile), profile, BuiltInKeys.income),
        ),
        'PKR 150000 per month',
      );
    });

    group('repeatable groups', () {
      test('render the shorthand when that is all the user gave', () {
        final profile = profileWith({
          BuiltInKeys.brothers: const RepeatableGroupValue(
            total: 2,
            marriedCount: 1,
          ).toJson(),
        });

        expect(
          BidiText.strip(
            valueOf(builder.build(profile), profile, BuiltInKeys.brothers),
          ),
          '2 (1 married)',
        );
      });

      test('list people when the user filled them in', () {
        var profile = buildTestProfile();
        final brothers = profile.schema.fieldByBuiltInKey(
          BuiltInKeys.brothers,
        )!;
        final nameId = brothers.groupFields.first.id;
        profile = profile.copyWith(
          values: {
            brothers.id: RepeatableGroupValue(
              total: 2,
              entries: [
                {nameId: 'Bilal'},
                {nameId: 'Usman'},
              ],
            ).toJson(),
          },
        );

        expect(
          BidiText.strip(
            valueOf(builder.build(profile), profile, BuiltInKeys.brothers),
          ),
          '2\nBilal\nUsman',
        );
      });

      test('an empty group does not print', () {
        final profile = profileWith({
          BuiltInKeys.brothers: const RepeatableGroupValue().toJson(),
        });

        expect(builder.build(profile).fieldCount, 0);
      });
    });
  });

  group('right-to-left documents', () {
    test('a phone number is isolated so it cannot reverse', () {
      final profile = profileWith({
        BuiltInKeys.phone: '+92 300 1234567',
      }, language: 'ur');

      final value = valueOf(
        builder.build(profile),
        profile,
        BuiltInKeys.phone,
      );

      expect(value, contains(BidiText.lri));
      expect(BidiText.strip(value), '+92 300 1234567');
    });

    test('prose keeps its flow, with only numeric runs isolated', () {
      final profile = profileWith({
        BuiltInKeys.education: 'ایم بی بی ایس، 2019 میں مکمل',
      }, language: 'ur');

      // A lone year needs no isolation, so nothing is inserted at all.
      expect(
        valueOf(builder.build(profile), profile, BuiltInKeys.education),
        isNot(contains(BidiText.lri)),
      );
    });

    test('an LTR document is left untouched', () {
      final profile = profileWith({BuiltInKeys.phone: '+92 300 1234567'});

      expect(
        valueOf(builder.build(profile), profile, BuiltInKeys.phone),
        '+92 300 1234567',
      );
    });

    test('Urdu resolves to the raster pipeline and Nastaliq (D1)', () {
      final doc = builder.build(profileWith({}, language: 'ur'));

      expect(doc.isRtl, isTrue);
      expect(doc.language.pipeline, RenderPipeline.raster);
      expect(doc.language.documentFontFamily, 'NotoNastaliqUrdu');
    });

    test('English resolves to the vector pipeline (D1)', () {
      final doc = builder.build(profileWith({}));

      expect(doc.isRtl, isFalse);
      expect(doc.language.pipeline, RenderPipeline.vector);
    });
  });

  group('Shareable mode (9.4)', () {
    test('omits the fields whose masking says omit', () {
      final profile = profileWith({
        BuiltInKeys.name: 'Ali',
        BuiltInKeys.phone: '+92 300 1234567',
        BuiltInKeys.income: const CurrencyValue(amount: 150000).toJson(),
      });

      final doc = builder.build(profile, mode: ExportMode.shareable);
      final ids = doc.sections.expand((s) => s.fields).map((f) => f.id);

      expect(
        ids,
        isNot(
          contains(profile.schema.fieldByBuiltInKey(BuiltInKeys.phone)!.id),
        ),
      );
      expect(
        ids,
        isNot(
          contains(profile.schema.fieldByBuiltInKey(BuiltInKeys.income)!.id),
        ),
      );
      expect(
        ids,
        contains(profile.schema.fieldByBuiltInKey(BuiltInKeys.name)!.id),
      );
    });

    test('generalises a date of birth to an age', () {
      final profile = profileWith({
        BuiltInKeys.dob: DateTime(1995, 3, 15).toIso8601String(),
      });

      final field = builder
          .build(profile, mode: ExportMode.shareable)
          .sections
          .expand((s) => s.fields)
          .single;

      expect(BidiText.strip(field.value), '31 years');
      expect(field.wasMasked, isTrue);
    });

    test('generalises an address to its last line', () {
      final profile = profileWith({
        BuiltInKeys.address: 'House 12, Gulberg, Lahore',
      });

      expect(
        builder
            .build(profile, mode: ExportMode.shareable)
            .sections
            .expand((s) => s.fields)
            .single
            .value,
        'Lahore',
      );
    });

    test('generalises an Urdu address, which uses the Arabic comma', () {
      // Regression: splitting on the ASCII comma alone left the full street
      // address in every Urdu, Sindhi and Pashto Shareable export — the exact
      // users this masking protects. Caught by a golden, pinned here.
      final profile = profileWith({
        BuiltInKeys.address: 'مکان نمبر 12، گلبرگ، لاہور',
      }, language: 'ur');

      expect(
        BidiText.strip(
          builder
              .build(profile, mode: ExportMode.shareable)
              .sections
              .expand((s) => s.fields)
              .single
              .value,
        ),
        'لاہور',
      );
    });

    test('Full mode leaves everything exactly as entered', () {
      final profile = profileWith({
        BuiltInKeys.address: 'House 12, Gulberg, Lahore',
      });

      final field = builder
          .build(profile)
          .sections
          .expand((s) => s.fields)
          .single;

      expect(field.value, 'House 12, Gulberg, Lahore');
      expect(field.wasMasked, isFalse);
    });
  });

  group('digit style', () {
    test('Arabic documents default to Eastern numerals', () {
      final base = buildTestProfile(documentLanguageCode: 'ar');
      final heightId = base.schema.fieldByBuiltInKey(BuiltInKeys.height)!.id;
      final profile = base.copyWith(
        values: {heightId: HeightValue.fromFeetInches(5, 9).toJson()},
      );

      final doc = builder.build(profile);

      expect(doc.digitStyle, DigitStyle.easternArabic);
      expect(
        BidiText.strip(doc.sections.expand((s) => s.fields).single.value),
        contains('٥'),
      );
    });

    test('Urdu keeps Western numerals by default', () {
      expect(
        builder.build(profileWith({}, language: 'ur')).digitStyle,
        DigitStyle.western,
      );
    });
  });
}
