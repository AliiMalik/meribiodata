import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/field_descriptor.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/section_descriptor.dart';
import 'package:meribiodata/domain/biodata/validation_rule.dart';

/// Produces a fresh id. Injectable so tests get deterministic schemas.
typedef IdGenerator = String Function();

/// Built-in keys, in one place. A typo here is a silently-untranslated label,
/// which is exactly the kind of bug that survives to production.
abstract final class BuiltInKeys {
  static const personal = 'personal';
  static const family = 'family';
  static const contact = 'contact';
  static const extras = 'extras';

  static const name = 'personal.name';
  static const caste = 'personal.caste';
  static const dob = 'personal.dob';
  static const bloodGroup = 'personal.bloodGroup';
  static const maslak = 'personal.maslak';
  static const height = 'personal.height';
  static const weight = 'personal.weight';
  static const education = 'personal.education';
  static const occupation = 'personal.occupation';
  static const income = 'personal.income';

  static const fatherName = 'family.fatherName';
  static const fatherOccupation = 'family.fatherOccupation';
  static const motherName = 'family.motherName';
  static const motherOccupation = 'family.motherOccupation';
  static const brothers = 'family.brothers';
  static const sisters = 'family.sisters';
  static const maternalFamily = 'family.maternalFamily';

  static const address = 'contact.address';
  static const phone = 'contact.phone';

  static const additionalInfo = 'extras.additionalInfo';

  static const groupPersonName = 'group.person.name';
  static const groupPersonMaritalStatus = 'group.person.maritalStatus';
  static const groupPersonOccupation = 'group.person.occupation';
}

/// The schema a new biodata starts with (§6.2).
///
/// Every part of it is editable afterwards — this is a starting point, not a
/// contract. Templates render whatever schema exists (§6.4), so nothing here
/// may be assumed present by rendering code.
abstract final class DefaultSchema {
  static const bloodGroups = <String>[
    'A+',
    'A−',
    'B+',
    'B−',
    'AB+',
    'AB−',
    'O+',
    'O−',
  ];

  /// Free text is always allowed on top of these — a fixed list would be
  /// wrong for someone, and being told your maslak "isn't an option" is a bad
  /// first impression.
  static const maslaks = <String>[
    'Hanafi',
    'Deobandi',
    'Barelvi',
    'Ahl-e-Hadith',
    'Shia',
  ];

  static const maritalStatuses = <String>['Married', 'Unmarried'];

  static BiodataSchema build({required IdGenerator newId}) {
    final personalId = newId();
    final familyId = newId();
    final contactId = newId();
    final extrasId = newId();

    final sections = <SectionDescriptor>[
      SectionDescriptor(
        id: personalId,
        order: 0,
        builtInKey: BuiltInKeys.personal,
        isDeletable: false,
      ),
      SectionDescriptor(
        id: familyId,
        order: 1,
        builtInKey: BuiltInKeys.family,
        isDeletable: false,
      ),
      SectionDescriptor(
        id: contactId,
        order: 2,
        builtInKey: BuiltInKeys.contact,
        isDeletable: false,
      ),
      SectionDescriptor(
        id: extrasId,
        order: 3,
        builtInKey: BuiltInKeys.extras,
        isVisible: false,
      ),
    ];

    // `order` is a position *within a section*, so the counter restarts for
    // each one. A single global counter would still sort correctly on a fresh
    // schema, but moving a field between sections would then land it in the
    // wrong place — its new order would be compared against numbers from a
    // different range.
    final nextOrder = <String, int>{};
    FieldDescriptor field(
      String sectionId,
      String builtInKey,
      FieldType type, {
      bool isRequired = false,
      bool isDeletable = true,
      bool isSensitive = false,
      bool isVisible = true,
      MaskingStrategy masking = MaskingStrategy.omit,
      List<String>? options,
      String? unitPreference,
      DateDisplay? dateDisplay,
      ValidationRule? validation,
      List<FieldDescriptor> groupFields = const [],
    }) => FieldDescriptor(
      id: newId(),
      type: type,
      sectionId: sectionId,
      order: nextOrder.update(sectionId, (n) => n + 1, ifAbsent: () => 0),
      builtInKey: builtInKey,
      isRequired: isRequired,
      isDeletable: isDeletable,
      isSensitive: isSensitive,
      isVisible: isVisible,
      masking: masking,
      options: options,
      unitPreference: unitPreference,
      dateDisplay: dateDisplay,
      validation: validation,
      groupFields: groupFields,
    );

    List<FieldDescriptor> personGroup() {
      var groupOrder = 0;
      FieldDescriptor inner(
        String builtInKey,
        FieldType type, {
        List<String>? options,
      }) => FieldDescriptor(
        id: newId(),
        type: type,
        sectionId: '',
        order: groupOrder++,
        builtInKey: builtInKey,
        options: options,
        validation: ValidationRule.shortText,
      );

      return [
        inner(BuiltInKeys.groupPersonName, FieldType.text),
        inner(
          BuiltInKeys.groupPersonMaritalStatus,
          FieldType.dropdown,
          options: maritalStatuses,
        ),
        inner(BuiltInKeys.groupPersonOccupation, FieldType.text),
      ];
    }

    final fields = <FieldDescriptor>[
      // --- Personal Details -------------------------------------------
      field(
        personalId,
        BuiltInKeys.name,
        FieldType.text,
        isRequired: true,
        // The one field the whole document is about. Everything else can go.
        isDeletable: false,
        validation: ValidationRule.name,
      ),
      field(
        personalId,
        BuiltInKeys.caste,
        FieldType.text,
        validation: ValidationRule.shortText,
      ),
      field(
        personalId,
        BuiltInKeys.dob,
        FieldType.date,
        isSensitive: true,
        // Age reads as normal discretion; an exact birth date does not need
        // to circulate in a WhatsApp group.
        masking: MaskingStrategy.generalise,
        dateDisplay: DateDisplay.dateAndAge,
        validation: ValidationRule.pastDate,
      ),
      field(
        personalId,
        BuiltInKeys.bloodGroup,
        FieldType.dropdown,
        options: bloodGroups,
      ),
      field(
        personalId,
        BuiltInKeys.maslak,
        FieldType.dropdown,
        options: maslaks,
        isSensitive: true,
      ),
      field(
        personalId,
        BuiltInKeys.height,
        FieldType.height,
        unitPreference: LengthUnit.feetInches.wire,
      ),
      field(
        personalId,
        BuiltInKeys.weight,
        FieldType.weight,
        unitPreference: MassUnit.kilograms.wire,
      ),
      field(
        personalId,
        BuiltInKeys.education,
        FieldType.multiline,
        validation: ValidationRule.longText,
      ),
      field(
        personalId,
        BuiltInKeys.occupation,
        FieldType.text,
        validation: ValidationRule.shortText,
      ),
      field(
        personalId,
        BuiltInKeys.income,
        FieldType.currency,
        isSensitive: true,
      ),

      // --- Family Details ---------------------------------------------
      field(
        familyId,
        BuiltInKeys.fatherName,
        FieldType.text,
        validation: ValidationRule.name,
      ),
      field(
        familyId,
        BuiltInKeys.fatherOccupation,
        FieldType.text,
        validation: ValidationRule.shortText,
      ),
      field(
        familyId,
        BuiltInKeys.motherName,
        FieldType.text,
        validation: ValidationRule.name,
      ),
      field(
        familyId,
        BuiltInKeys.motherOccupation,
        FieldType.text,
        validation: ValidationRule.shortText,
      ),
      field(
        familyId,
        BuiltInKeys.brothers,
        FieldType.repeatableGroup,
        groupFields: personGroup(),
      ),
      field(
        familyId,
        BuiltInKeys.sisters,
        FieldType.repeatableGroup,
        groupFields: personGroup(),
      ),
      field(
        familyId,
        BuiltInKeys.maternalFamily,
        FieldType.multiline,
        validation: ValidationRule.longText,
      ),

      // --- Contact & Address ------------------------------------------
      field(
        contactId,
        BuiltInKeys.address,
        FieldType.multiline,
        isSensitive: true,
        // City instead of a street address reads as discretion, not evasion.
        masking: MaskingStrategy.generalise,
        validation: ValidationRule.longText,
      ),
      field(
        contactId,
        BuiltInKeys.phone,
        FieldType.text,
        isSensitive: true,
        validation: ValidationRule.phone,
      ),

      // --- Optional extras, off by default ----------------------------
      field(
        extrasId,
        BuiltInKeys.additionalInfo,
        FieldType.multiline,
        isVisible: false,
        validation: ValidationRule.longText,
      ),
    ];

    return BiodataSchema(sections: sections, fields: fields);
  }
}
