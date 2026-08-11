import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/label_resolver.dart';
import 'package:meribiodata/domain/biodata/schema_editor.dart';

import '../support/schema_fixtures.dart';

void main() {
  const resolver = LabelResolver(FakeBuiltInLabels.standard);
  late BiodataSchema schema;
  late String casteId;

  setUp(() {
    schema = buildTestSchema();
    casteId = schema.fieldByBuiltInKey(BuiltInKeys.caste)!.id;
  });

  group('resolution order (§6.1)', () {
    test('1. the user override for the requested language wins', () {
      final edited = schema.renameField(
        casteId,
        label: 'Zaat',
        localeCode: 'en',
      );

      expect(
        resolver.fieldLabel(edited.fieldById(casteId)!, 'en'),
        'Zaat',
      );
    });

    test('2. the shipped label for the requested language outranks a rename '
        'made in another language (D7)', () {
      final edited = schema.renameField(
        casteId,
        label: 'ذات / برادری / قوم',
        localeCode: 'ur',
      );

      // The D7 ruling. An Urdu rename must not put Urdu words into the English
      // document when English has a correct shipped label of its own — that
      // blemish ends up in the exported PDF.
      expect(
        resolver.fieldLabel(edited.fieldById(casteId)!, 'en'),
        'Caste / Biradari',
      );
    });

    test('3. a rename in another language, when this one has no shipped '
        'label — a custom field', () {
      final withCustom = schema.addField(
        sectionId: schema.sections.first.id,
        type: FieldType.text,
        label: 'Hobbies',
        localeCode: 'en',
        newId: () => 'custom-1',
      );

      // No shipped label exists for a custom field in any language, so
      // borrowing is the only alternative to showing a raw id.
      expect(
        resolver.fieldLabel(withCustom.fieldById('custom-1')!, 'ur'),
        'Hobbies',
      );
      expect(
        resolver.isFieldLabelBorrowed(withCustom.fieldById('custom-1')!, 'ur'),
        isTrue,
      );
    });

    test('the shipped label for the requested language, with no renames at all',
        () {
      expect(
        resolver.fieldLabel(schema.fieldById(casteId)!, 'ur'),
        'ذات / برادری',
      );
    });

    test('4. the shipped English label when the language has none', () {
      final bloodGroup = schema.fieldByBuiltInKey(BuiltInKeys.bloodGroup)!;

      expect(resolver.fieldLabel(bloodGroup, 'ur'), 'Blood Group');
    });

    test('5. the raw id, when there is nothing else at all', () {
      final orphan = schema
          .addField(
            sectionId: schema.sections.first.id,
            type: FieldType.text,
            label: 'Temp',
            localeCode: 'en',
            newId: () => 'orphan',
          )
          .updateField('orphan', (f) => f.copyWith(labels: const {}));

      expect(resolver.fieldLabel(orphan.fieldById('orphan')!, 'en'), 'orphan');
    });
  });

  group('renaming is per-language (§6.1)', () {
    test('an Urdu rename does not rename the English document', () {
      final edited = schema
          .renameField(casteId, label: 'Zaat/Biradari', localeCode: 'en')
          .renameField(casteId, label: 'قوم', localeCode: 'ur');

      final field = edited.fieldById(casteId)!;
      expect(resolver.fieldLabel(field, 'en'), 'Zaat/Biradari');
      expect(resolver.fieldLabel(field, 'ur'), 'قوم');
    });

    test('clearing a rename falls back to the shipped label, not to empty', () {
      final edited = schema
          .renameField(casteId, label: 'Zaat', localeCode: 'en')
          .clearFieldRename(casteId, 'en');

      expect(
        resolver.fieldLabel(edited.fieldById(casteId)!, 'en'),
        'Caste / Biradari',
      );
    });

    test('a borrowed label is flagged so the UI can explain itself', () {
      // Only a custom field can borrow now, so only a custom field is flagged.
      final edited = schema.addField(
        sectionId: schema.sections.first.id,
        type: FieldType.text,
        label: 'Hobbies',
        localeCode: 'en',
        newId: () => 'custom-1',
      );
      final field = edited.fieldById('custom-1')!;

      expect(resolver.isFieldLabelBorrowed(field, 'ur'), isTrue);
      expect(resolver.isFieldLabelBorrowed(field, 'en'), isFalse);
    });

    test('a built-in field showing its own shipped label is never flagged '
        'as borrowed (D7)', () {
      final edited = schema.renameField(
        casteId,
        label: 'قوم',
        localeCode: 'ur',
      );
      final field = edited.fieldById(casteId)!;

      // English resolves to its shipped label, so the chip would be a lie.
      expect(resolver.fieldLabel(field, 'en'), 'Caste / Biradari');
      expect(resolver.isFieldLabelBorrowed(field, 'en'), isFalse);
      expect(resolver.isFieldLabelBorrowed(field, 'ur'), isFalse);
    });

    test('a built-in field with no shipped label for this language still '
        'borrows, and is flagged', () {
      final bloodGroupId = schema.fieldByBuiltInKey(BuiltInKeys.bloodGroup)!.id;
      final edited = schema.renameField(
        bloodGroupId,
        label: 'Blood Type',
        localeCode: 'en',
      );
      final field = edited.fieldById(bloodGroupId)!;

      // No Urdu translation ships for this one, so the English rename is the
      // best available — better than the untouched English shipped label.
      expect(resolver.fieldLabel(field, 'ur'), 'Blood Type');
      expect(resolver.isFieldLabelBorrowed(field, 'ur'), isTrue);
    });
  });

  test('picking "any other language" is deterministic, preferring English', () {
    final edited = schema
        .renameField(casteId, label: 'Zaat', localeCode: 'en')
        .renameField(casteId, label: 'قوم', localeCode: 'ur');

    // 'sd' has no override of its own; English wins over Urdu.
    expect(resolver.fieldLabel(edited.fieldById(casteId)!, 'sd'), 'Zaat');
  });

  test('section titles follow the same order', () {
    final personal = schema.sections.firstWhere(
      (s) => s.builtInKey == BuiltInKeys.personal,
    );

    expect(resolver.sectionTitle(personal, 'ur'), 'ذاتی معلومات');
    expect(resolver.sectionTitle(personal, 'en'), 'Personal Details');

    final renamed = schema
        .renameSection(personal.id, title: 'About Him', localeCode: 'en')
        .sectionById(personal.id)!;
    expect(resolver.sectionTitle(renamed, 'en'), 'About Him');

    // D7: the shipped Urdu title outranks the English rename, so an Urdu
    // document keeps its reviewed heading and nothing is flagged.
    expect(resolver.sectionTitle(renamed, 'ur'), 'ذاتی معلومات');
    expect(resolver.isSectionTitleBorrowed(renamed, 'ur'), isFalse);

    // A section with no shipped title for the language still borrows.
    expect(resolver.sectionTitle(renamed, 'sd'), 'About Him');
    expect(resolver.isSectionTitleBorrowed(renamed, 'sd'), isTrue);
  });
}
