import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/field_descriptor.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/section_descriptor.dart';
import 'package:meribiodata/domain/biodata/validation_rule.dart';

/// Pure schema mutations. No Flutter, no storage, no async — every operation
/// takes a schema and returns a new one, which makes the whole editing surface
/// exhaustively testable and trivially undoable.
///
/// Throws [SchemaException] rather than silently ignoring an illegal edit: a
/// delete that quietly does nothing is worse than an error message.
extension SchemaEditing on BiodataSchema {
  // --- Fields ----------------------------------------------------------

  BiodataSchema addField({
    required String sectionId,
    required FieldType type,
    required String label,
    required String localeCode,
    required IdGenerator newId,
    bool isRequired = false,
    bool isSensitive = false,
    List<String>? options,
    int? position,
  }) {
    if (fields.length >= SchemaLimits.maxFields) {
      throw const SchemaException(SchemaError.fieldLimitReached);
    }
    if (sectionById(sectionId) == null) {
      throw const SchemaException(SchemaError.sectionNotFound);
    }
    _requireUsableLabel(label);

    final siblings = fieldsIn(sectionId);
    final index = position?.clamp(0, siblings.length) ?? siblings.length;

    final created = FieldDescriptor(
      id: newId(),
      type: type,
      sectionId: sectionId,
      order: index,
      labels: {localeCode: label.trim()},
      isRequired: isRequired,
      isSensitive: isSensitive,
      options: options,
      validation: _defaultValidationFor(type),
    );

    final reordered = [...siblings]..insert(index, created);
    return _replacingSection(sectionId, reordered);
  }

  /// Renames a field **for one language only** (§6.1). Renaming in Urdu must
  /// not rename it in English.
  BiodataSchema renameField(
    String fieldId, {
    required String label,
    required String localeCode,
  }) {
    final field = _requireField(fieldId);
    _requireUsableLabel(label);
    return copyWith(
      fields: [
        for (final f in fields)
          if (f.id == field.id)
            f.copyWith(labels: {...f.labels, localeCode: label.trim()})
          else
            f,
      ],
    );
  }

  /// Drops the user's override for one language, falling back to the shipped
  /// label. Distinct from renaming to the shipped text, which would freeze it.
  BiodataSchema clearFieldRename(String fieldId, String localeCode) {
    final field = _requireField(fieldId);
    return copyWith(
      fields: [
        for (final f in fields)
          if (f.id == field.id)
            f.copyWith(labels: {...f.labels}..remove(localeCode))
          else
            f,
      ],
    );
  }

  BiodataSchema updateField(
    String fieldId,
    FieldDescriptor Function(FieldDescriptor) update,
  ) {
    final field = _requireField(fieldId);
    return copyWith(
      fields: [
        for (final f in fields)
          if (f.id == field.id) update(f) else f,
      ],
    );
  }

  /// Hides a field without touching its data (§6.1) — the user can unhide it
  /// and their answer is still there.
  BiodataSchema setFieldVisible(String fieldId, {required bool isVisible}) =>
      updateField(fieldId, (f) => f.copyWith(isVisible: isVisible));

  BiodataSchema setFieldRequired(String fieldId, {required bool isRequired}) =>
      updateField(fieldId, (f) => f.copyWith(isRequired: isRequired));

  BiodataSchema setFieldSensitive(
    String fieldId, {
    required bool isSensitive,
  }) => updateField(fieldId, (f) => f.copyWith(isSensitive: isSensitive));

  BiodataSchema deleteField(String fieldId) {
    final field = _requireField(fieldId);
    if (!field.isDeletable) {
      throw const SchemaException(SchemaError.fieldNotDeletable);
    }
    final remaining = fields.where((f) => f.id != fieldId).toList();
    return copyWith(fields: remaining)._renumbering(field.sectionId);
  }

  /// Moves a field within its section.
  BiodataSchema moveField(String fieldId, int newIndex) {
    final field = _requireField(fieldId);
    final siblings = fieldsIn(field.sectionId);
    final from = siblings.indexWhere((f) => f.id == fieldId);
    final to = newIndex.clamp(0, siblings.length - 1);
    if (from == to) return this;

    final reordered = [...siblings]
      ..removeAt(from)
      ..insert(to, field);
    return _replacingSection(field.sectionId, reordered);
  }

  /// Moves a field to a different section, appending it at the end.
  BiodataSchema moveFieldToSection(String fieldId, String sectionId) {
    final field = _requireField(fieldId);
    if (sectionById(sectionId) == null) {
      throw const SchemaException(SchemaError.sectionNotFound);
    }
    if (field.sectionId == sectionId) return this;

    final target = fieldsIn(sectionId);
    final moved = field.copyWith(sectionId: sectionId, order: target.length);
    return copyWith(
      fields: [
        for (final f in fields)
          if (f.id == fieldId) moved else f,
      ],
    )._renumbering(field.sectionId);
  }

  // --- Sections --------------------------------------------------------

  BiodataSchema addSection({
    required String title,
    required String localeCode,
    required IdGenerator newId,
    int? position,
  }) {
    if (sections.length >= SchemaLimits.maxSections) {
      throw const SchemaException(SchemaError.sectionLimitReached);
    }
    _requireUsableLabel(title);

    final ordered = orderedSections;
    final index = position?.clamp(0, ordered.length) ?? ordered.length;
    final created = SectionDescriptor(
      id: newId(),
      order: index,
      titles: {localeCode: title.trim()},
    );

    final reordered = [...ordered]..insert(index, created);
    return copyWith(
      sections: [
        for (var i = 0; i < reordered.length; i++)
          reordered[i].copyWith(order: i),
      ],
    );
  }

  BiodataSchema renameSection(
    String sectionId, {
    required String title,
    required String localeCode,
  }) {
    final section = _requireSection(sectionId);
    _requireUsableLabel(title);
    return copyWith(
      sections: [
        for (final s in sections)
          if (s.id == section.id)
            s.copyWith(titles: {...s.titles, localeCode: title.trim()})
          else
            s,
      ],
    );
  }

  BiodataSchema setSectionVisible(
    String sectionId, {
    required bool isVisible,
  }) {
    _requireSection(sectionId);
    return copyWith(
      sections: [
        for (final s in sections)
          if (s.id == sectionId) s.copyWith(isVisible: isVisible) else s,
      ],
    );
  }

  /// Deleting a section deletes its fields with it. The caller is responsible
  /// for confirming — this is the one schema edit that destroys answers.
  BiodataSchema deleteSection(String sectionId) {
    final section = _requireSection(sectionId);
    if (!section.isDeletable) {
      throw const SchemaException(SchemaError.sectionNotDeletable);
    }
    final remaining = orderedSections.where((s) => s.id != sectionId).toList();
    return copyWith(
      sections: [
        for (var i = 0; i < remaining.length; i++)
          remaining[i].copyWith(order: i),
      ],
      fields: fields.where((f) => f.sectionId != sectionId).toList(),
    );
  }

  BiodataSchema moveSection(String sectionId, int newIndex) {
    final section = _requireSection(sectionId);
    final ordered = orderedSections;
    final from = ordered.indexWhere((s) => s.id == sectionId);
    final to = newIndex.clamp(0, ordered.length - 1);
    if (from == to) return this;

    final reordered = [...ordered]
      ..removeAt(from)
      ..insert(to, section);
    return copyWith(
      sections: [
        for (var i = 0; i < reordered.length; i++)
          reordered[i].copyWith(order: i),
      ],
    );
  }

  /// Field ids that a delete would orphan values for. The caller uses this to
  /// clean up the profile's value map in the same operation.
  List<String> fieldIdsIn(String sectionId) =>
      fields.where((f) => f.sectionId == sectionId).map((f) => f.id).toList();

  // --- Internals -------------------------------------------------------

  FieldDescriptor _requireField(String id) =>
      fieldById(id) ?? (throw const SchemaException(SchemaError.fieldNotFound));

  SectionDescriptor _requireSection(String id) =>
      sectionById(id) ??
      (throw const SchemaException(SchemaError.sectionNotFound));

  static void _requireUsableLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw const SchemaException(SchemaError.labelEmpty);
    }
    if (trimmed.runes.length > SchemaLimits.maxLabelLength) {
      throw const SchemaException(SchemaError.labelTooLong);
    }
  }

  BiodataSchema _replacingSection(
    String sectionId,
    List<FieldDescriptor> ordered,
  ) => copyWith(
    fields: [
      ...fields.where((f) => f.sectionId != sectionId),
      for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(order: i),
    ],
  );

  BiodataSchema _renumbering(String sectionId) =>
      _replacingSection(sectionId, fieldsIn(sectionId));

  static ValidationRule? _defaultValidationFor(FieldType type) =>
      switch (type) {
        FieldType.multiline => ValidationRule.longText,
        FieldType.text || FieldType.dropdown => ValidationRule.shortText,
        _ => null,
      };
}
