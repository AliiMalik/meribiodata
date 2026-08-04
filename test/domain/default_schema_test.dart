import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';

import '../support/schema_fixtures.dart';

void main() {
  late BiodataSchema schema;

  setUp(() => schema = buildTestSchema());

  test('seeds the three mandatory sections plus optional extras', () {
    expect(
      schema.orderedSections.map((s) => s.builtInKey),
      [
        BuiltInKeys.personal,
        BuiltInKeys.family,
        BuiltInKeys.contact,
        BuiltInKeys.extras,
      ],
    );
  });

  test('the three mandatory sections cannot be deleted', () {
    for (final key in [
      BuiltInKeys.personal,
      BuiltInKeys.family,
      BuiltInKeys.contact,
    ]) {
      final section = schema.sections.firstWhere((s) => s.builtInKey == key);
      expect(section.isDeletable, isFalse, reason: key);
    }
  });

  test('extras section is seeded hidden', () {
    final extras = schema.sections.firstWhere(
      (s) => s.builtInKey == BuiltInKeys.extras,
    );
    expect(extras.isVisible, isFalse);
  });

  test('Name is required and undeletable; nothing else is undeletable', () {
    final name = schema.fieldByBuiltInKey(BuiltInKeys.name)!;
    expect(name.isRequired, isTrue);
    expect(name.isDeletable, isFalse);

    final others = schema.fields.where((f) => f.builtInKey != BuiltInKeys.name);
    expect(others.every((f) => f.isDeletable), isTrue);
  });

  test('9.4 sensitive defaults match the spec', () {
    const expectedSensitive = {
      BuiltInKeys.phone,
      BuiltInKeys.income,
      BuiltInKeys.address,
      BuiltInKeys.maslak,
      BuiltInKeys.dob,
    };

    final actual = schema.sensitiveFields.map((f) => f.builtInKey).toSet();
    expect(actual, expectedSensitive);
  });

  test('address and DOB generalise rather than vanish in Shareable mode', () {
    expect(
      schema.fieldByBuiltInKey(BuiltInKeys.address)!.masking,
      MaskingStrategy.generalise,
    );
    expect(
      schema.fieldByBuiltInKey(BuiltInKeys.dob)!.masking,
      MaskingStrategy.generalise,
    );
    expect(
      schema.fieldByBuiltInKey(BuiltInKeys.income)!.masking,
      MaskingStrategy.omit,
    );
  });

  test('field types match §6.2', () {
    const expected = {
      BuiltInKeys.name: FieldType.text,
      BuiltInKeys.dob: FieldType.date,
      BuiltInKeys.bloodGroup: FieldType.dropdown,
      BuiltInKeys.maslak: FieldType.dropdown,
      BuiltInKeys.height: FieldType.height,
      BuiltInKeys.weight: FieldType.weight,
      BuiltInKeys.education: FieldType.multiline,
      BuiltInKeys.income: FieldType.currency,
      BuiltInKeys.brothers: FieldType.repeatableGroup,
      BuiltInKeys.sisters: FieldType.repeatableGroup,
      BuiltInKeys.address: FieldType.multiline,
    };

    for (final entry in expected.entries) {
      expect(
        schema.fieldByBuiltInKey(entry.key)!.type,
        entry.value,
        reason: entry.key,
      );
    }
  });

  test('sibling groups carry name, marital status and occupation', () {
    for (final key in [BuiltInKeys.brothers, BuiltInKeys.sisters]) {
      final group = schema.fieldByBuiltInKey(key)!;
      expect(
        group.groupFields.map((f) => f.builtInKey),
        [
          BuiltInKeys.groupPersonName,
          BuiltInKeys.groupPersonMaritalStatus,
          BuiltInKeys.groupPersonOccupation,
        ],
        reason: key,
      );
    }
  });

  test('every field id is unique', () {
    final ids = schema.fields.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every field belongs to a section that exists', () {
    for (final field in schema.fields) {
      expect(
        schema.sectionById(field.sectionId),
        isNotNull,
        reason: field.builtInKey,
      );
    }
  });

  test('the seed fits inside the §6.3 caps with room to grow', () {
    expect(schema.fields.length, lessThan(SchemaLimits.maxFields));
    expect(schema.sections.length, lessThan(SchemaLimits.maxSections));
  });

  test('phone carries phone validation, so a typo is caught on entry', () {
    final phone = schema.fieldByBuiltInKey(BuiltInKeys.phone)!;
    expect(phone.validation?.isPhoneNumber, isTrue);
  });

  test('survives a JSON round trip unchanged', () {
    final restored = BiodataSchema.fromJson(schema.toJson());
    expect(restored, schema);
  });
}
