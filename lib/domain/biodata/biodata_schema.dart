import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meribiodata/domain/biodata/field_descriptor.dart';
import 'package:meribiodata/domain/biodata/section_descriptor.dart';

part 'biodata_schema.freezed.dart';
part 'biodata_schema.g.dart';

/// Caps from §6.3. They exist so a pathological schema cannot break a template
/// or produce a document that clips instead of paginating.
abstract final class SchemaLimits {
  static const maxFields = 60;
  static const maxSections = 10;
  static const maxLabelLength = 60;
  static const maxGroupEntries = 20;
}

/// Why a schema mutation was refused. The UI localizes these.
enum SchemaError {
  fieldLimitReached,
  sectionLimitReached,
  fieldNotFound,
  sectionNotFound,
  fieldNotDeletable,
  sectionNotDeletable,
  sectionNotEmpty,
  labelTooLong,
  labelEmpty,
}

class SchemaException implements Exception {
  const SchemaException(this.error);

  final SchemaError error;

  @override
  String toString() => 'SchemaException: ${error.name}';
}

/// The full field/section layout of one biodata.
///
/// Per `docs/decisions.md` D6 each profile owns its own copy, so editing one
/// biodata's labels never touches another's.
@freezed
abstract class BiodataSchema with _$BiodataSchema {
  const factory BiodataSchema({
    required List<SectionDescriptor> sections,
    required List<FieldDescriptor> fields,

    /// Bumped when the *shape* of the seeded schema changes, so a restore from
    /// an older backup can be migrated rather than misread (9.5).
    @Default(1) int version,
  }) = _BiodataSchema;

  const BiodataSchema._();

  factory BiodataSchema.fromJson(Map<String, dynamic> json) =>
      _$BiodataSchemaFromJson(json);

  List<SectionDescriptor> get orderedSections =>
      [...sections]..sort((a, b) => a.order.compareTo(b.order));

  List<SectionDescriptor> get visibleSections =>
      orderedSections.where((s) => s.isVisible).toList();

  /// Fields of one section, in order. Hidden fields are included — the form
  /// editor still shows them, only the document skips them.
  List<FieldDescriptor> fieldsIn(String sectionId) =>
      [...fields.where((f) => f.sectionId == sectionId)]
        ..sort((a, b) => a.order.compareTo(b.order));

  List<FieldDescriptor> visibleFieldsIn(String sectionId) =>
      fieldsIn(sectionId).where((f) => f.isVisible).toList();

  FieldDescriptor? fieldById(String id) =>
      fields.where((f) => f.id == id).firstOrNull;

  SectionDescriptor? sectionById(String id) =>
      sections.where((s) => s.id == id).firstOrNull;

  FieldDescriptor? fieldByBuiltInKey(String key) =>
      fields.where((f) => f.builtInKey == key).firstOrNull;

  /// Fields that a Shareable export would omit or mask (9.4).
  List<FieldDescriptor> get sensitiveFields =>
      fields.where((f) => f.isSensitive).toList();
}
