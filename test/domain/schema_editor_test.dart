import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/schema_editor.dart';

import '../support/schema_fixtures.dart';

void main() {
  late BiodataSchema schema;
  late String personalId;

  setUp(() {
    schema = buildTestSchema();
    personalId = schema.sections
        .firstWhere((s) => s.builtInKey == BuiltInKeys.personal)
        .id;
  });

  group('adding fields', () {
    test('appends to the section and takes the next order', () {
      final before = schema.fieldsIn(personalId).length;
      final edited = schema.addField(
        sectionId: personalId,
        type: FieldType.text,
        label: 'Nationality',
        localeCode: 'en',
        newId: () => 'custom-1',
      );

      final fields = edited.fieldsIn(personalId);
      expect(fields.length, before + 1);
      expect(fields.last.id, 'custom-1');
      expect(fields.last.order, before);
      expect(fields.last.isCustom, isTrue);
    });

    test('can be inserted at a position, renumbering the rest', () {
      final edited = schema.addField(
        sectionId: personalId,
        type: FieldType.text,
        label: 'Nickname',
        localeCode: 'en',
        newId: () => 'custom-1',
        position: 0,
      );

      final fields = edited.fieldsIn(personalId);
      expect(fields.first.id, 'custom-1');
      expect(
        [for (var i = 0; i < fields.length; i++) fields[i].order],
        [
          for (var i = 0; i < fields.length; i++) i,
        ],
      );
    });

    test('refuses an empty or whitespace label', () {
      expect(
        () => schema.addField(
          sectionId: personalId,
          type: FieldType.text,
          label: '   ',
          localeCode: 'en',
          newId: () => 'x',
        ),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.error,
            'error',
            SchemaError.labelEmpty,
          ),
        ),
      );
    });

    test('refuses a label past the cap', () {
      expect(
        () => schema.addField(
          sectionId: personalId,
          type: FieldType.text,
          label: 'x' * (SchemaLimits.maxLabelLength + 1),
          localeCode: 'en',
          newId: () => 'x',
        ),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.error,
            'error',
            SchemaError.labelTooLong,
          ),
        ),
      );
    });

    test('refuses an unknown section', () {
      expect(
        () => schema.addField(
          sectionId: 'nope',
          type: FieldType.text,
          label: 'X',
          localeCode: 'en',
          newId: () => 'x',
        ),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.error,
            'error',
            SchemaError.sectionNotFound,
          ),
        ),
      );
    });

    test('enforces the 60-field cap (§6.3)', () {
      var edited = schema;
      var n = 0;
      while (edited.fields.length < SchemaLimits.maxFields) {
        edited = edited.addField(
          sectionId: personalId,
          type: FieldType.text,
          label: 'Extra ${n++}',
          localeCode: 'en',
          newId: () => 'extra-$n',
        );
      }

      expect(edited.fields.length, SchemaLimits.maxFields);
      expect(
        () => edited.addField(
          sectionId: personalId,
          type: FieldType.text,
          label: 'One too many',
          localeCode: 'en',
          newId: () => 'boom',
        ),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.error,
            'error',
            SchemaError.fieldLimitReached,
          ),
        ),
      );
    });
  });

  group('hiding and deleting', () {
    test('hiding keeps the field in the schema so its data survives', () {
      final casteId = schema.fieldByBuiltInKey(BuiltInKeys.caste)!.id;
      final edited = schema.setFieldVisible(casteId, isVisible: false);

      expect(edited.fieldById(casteId), isNotNull);
      expect(edited.fieldById(casteId)!.isVisible, isFalse);
      expect(
        edited.visibleFieldsIn(personalId).map((f) => f.id),
        isNot(contains(casteId)),
      );
    });

    test('deleting removes it and renumbers the section', () {
      final casteId = schema.fieldByBuiltInKey(BuiltInKeys.caste)!.id;
      final edited = schema.deleteField(casteId);

      expect(edited.fieldById(casteId), isNull);
      final fields = edited.fieldsIn(personalId);
      expect(
        [for (final f in fields) f.order],
        [
          for (var i = 0; i < fields.length; i++) i,
        ],
      );
    });

    test('Name cannot be deleted', () {
      final nameId = schema.fieldByBuiltInKey(BuiltInKeys.name)!.id;

      expect(
        () => schema.deleteField(nameId),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.error,
            'error',
            SchemaError.fieldNotDeletable,
          ),
        ),
      );
    });

    test('a mandatory section cannot be deleted', () {
      expect(
        () => schema.deleteSection(personalId),
        throwsA(
          isA<SchemaException>().having(
            (e) => e.error,
            'error',
            SchemaError.sectionNotDeletable,
          ),
        ),
      );
    });

    test('deleting a custom section takes its fields with it', () {
      var edited = schema.addSection(
        title: 'References',
        localeCode: 'en',
        newId: () => 'section-x',
      );
      edited = edited.addField(
        sectionId: 'section-x',
        type: FieldType.text,
        label: 'Referee',
        localeCode: 'en',
        newId: () => 'field-x',
      );

      expect(edited.fieldIdsIn('section-x'), ['field-x']);

      final after = edited.deleteSection('section-x');
      expect(after.sectionById('section-x'), isNull);
      expect(after.fieldById('field-x'), isNull);
    });
  });

  group('reordering', () {
    test('moving a field up renumbers everything consistently', () {
      final fields = schema.fieldsIn(personalId);
      final third = fields[2];

      final edited = schema.moveField(third.id, 0);
      final after = edited.fieldsIn(personalId);

      expect(after.first.id, third.id);
      expect(
        [for (final f in after) f.order],
        [
          for (var i = 0; i < after.length; i++) i,
        ],
      );
      expect(after.length, fields.length);
    });

    test('moving to the same index is a no-op', () {
      final first = schema.fieldsIn(personalId).first;
      expect(schema.moveField(first.id, 0), schema);
    });

    test('an out-of-range index clamps instead of throwing', () {
      final first = schema.fieldsIn(personalId).first;
      final edited = schema.moveField(first.id, 999);

      expect(edited.fieldsIn(personalId).last.id, first.id);
    });

    test('moving between sections appends and renumbers both', () {
      final familyId = schema.sections
          .firstWhere((s) => s.builtInKey == BuiltInKeys.family)
          .id;
      final casteId = schema.fieldByBuiltInKey(BuiltInKeys.caste)!.id;

      final edited = schema.moveFieldToSection(casteId, familyId);

      expect(edited.fieldById(casteId)!.sectionId, familyId);
      expect(edited.fieldsIn(familyId).last.id, casteId);

      final personal = edited.fieldsIn(personalId);
      expect(
        [for (final f in personal) f.order],
        [
          for (var i = 0; i < personal.length; i++) i,
        ],
      );
    });

    test('sections reorder and renumber', () {
      final contactId = schema.sections
          .firstWhere((s) => s.builtInKey == BuiltInKeys.contact)
          .id;

      final edited = schema.moveSection(contactId, 0);

      expect(edited.orderedSections.first.id, contactId);
      expect(
        [for (final s in edited.orderedSections) s.order],
        [
          for (var i = 0; i < edited.sections.length; i++) i,
        ],
      );
    });
  });

  test('enforces the 10-section cap (§6.3)', () {
    var edited = schema;
    var n = 0;
    while (edited.sections.length < SchemaLimits.maxSections) {
      edited = edited.addSection(
        title: 'Section ${n++}',
        localeCode: 'en',
        newId: () => 'section-$n',
      );
    }

    expect(
      () => edited.addSection(
        title: 'One too many',
        localeCode: 'en',
        newId: () => 'boom',
      ),
      throwsA(
        isA<SchemaException>().having(
          (e) => e.error,
          'error',
          SchemaError.sectionLimitReached,
        ),
      ),
    );
  });

  test('every mutation leaves the schema JSON-serializable', () {
    final casteId = schema.fieldByBuiltInKey(BuiltInKeys.caste)!.id;
    final edited = schema
        .renameField(casteId, label: 'قوم', localeCode: 'ur')
        .setFieldSensitive(casteId, isSensitive: true)
        .addSection(title: 'X', localeCode: 'en', newId: () => 's')
        .addField(
          sectionId: 's',
          type: FieldType.currency,
          label: 'Dowry expectation',
          localeCode: 'en',
          newId: () => 'f',
        );

    expect(BiodataSchema.fromJson(edited.toJson()), edited);
  });
}
