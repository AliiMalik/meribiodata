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

    test('2. an override in another language is used before the shipped '
        'label, because the user has said something about this field', () {
      final edited = schema.renameField(
        casteId,
        label: 'ذات / برادری / قوم',
        localeCode: 'ur',
      );

      expect(
        resolver.fieldLabel(edited.fieldById(casteId)!, 'en'),
        'ذات / برادری / قوم',
      );
    });

    test('3. the shipped label for the requested language', () {
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
      final edited = schema.renameField(
        casteId,
        label: 'قوم',
        localeCode: 'ur',
      );
      final field = edited.fieldById(casteId)!;

      expect(
        resolver.isBorrowedFromAnotherLanguage(field.labels, 'en'),
        isTrue,
      );
      expect(
        resolver.isBorrowedFromAnotherLanguage(field.labels, 'ur'),
        isFalse,
      );
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

    // Step 2 of §6.1 outranks the shipped label, so an English rename shows
    // through in Urdu too — flagged as borrowed rather than silently applied.
    // See the "renaming across languages" note in docs/decisions.md D7.
    expect(resolver.sectionTitle(renamed, 'ur'), 'About Him');
    expect(
      resolver.isBorrowedFromAnotherLanguage(renamed.titles, 'ur'),
      isTrue,
    );
  });
}
