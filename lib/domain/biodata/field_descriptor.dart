import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/validation_rule.dart';

part 'field_descriptor.freezed.dart';
part 'field_descriptor.g.dart';

/// One field in a biodata's schema.
///
/// Every label in this app is user-editable, and fields can be reordered,
/// hidden, deleted and created by the user — so the form is data, never a
/// hardcoded widget tree (§6).
@freezed
abstract class FieldDescriptor with _$FieldDescriptor {
  const factory FieldDescriptor({
    /// Stable UUID. Never changes, including across renames and reorders —
    /// it is the key that values are stored under.
    required String id,
    required FieldType type,
    required String sectionId,
    required int order,

    /// Identifies a field that came from the default schema, e.g.
    /// `personal.caste`. Null for user-created fields. Used to look up the
    /// built-in translated label and to re-seed on "reset to defaults".
    String? builtInKey,

    /// User-supplied label overrides, keyed by locale code.
    ///
    /// Layered *over* the built-in i18n strings rather than replacing them, so
    /// renaming "Caste" to "Zaat/Biradari" in the Urdu document leaves the
    /// English document alone (§6.1). Empty for an unrenamed built-in field.
    @Default(<String, String>{}) Map<String, String> labels,

    @Default(false) bool isRequired,

    /// Hidden fields keep their data — they just do not render in the
    /// document. Hiding is not deleting.
    @Default(true) bool isVisible,

    /// False for the minimal core set (currently: Name). Everything else can
    /// be removed.
    @Default(true) bool isDeletable,

    /// Drives the Full vs Shareable export modes (9.4).
    @Default(false) bool isSensitive,

    /// How this field behaves in a Shareable export. Stored from M2 so the
    /// M5 export modes need no schema migration; nothing reads it yet.
    @Default(MaskingStrategy.omit) MaskingStrategy masking,

    /// Choices for [FieldType.dropdown]. A dropdown always also accepts free
    /// text — a fixed list of castes or maslaks would be wrong for someone.
    List<String>? options,

    /// Display unit for height/weight/currency. Values are always *stored*
    /// canonically (cm, kg); this only affects presentation and input.
    String? unitPreference,

    /// For [FieldType.date]: whether to print the date, the derived age, or
    /// both. Many families prefer age only (§6.2).
    DateDisplay? dateDisplay,

    /// Field descriptors for the rows of a [FieldType.repeatableGroup].
    @Default(<FieldDescriptor>[]) List<FieldDescriptor> groupFields,

    ValidationRule? validation,
  }) = _FieldDescriptor;

  const FieldDescriptor._();

  factory FieldDescriptor.fromJson(Map<String, dynamic> json) =>
      _$FieldDescriptorFromJson(json);

  /// True when the user has renamed this field in any language.
  bool get isRenamed => labels.isNotEmpty;

  /// A user-created field has no built-in translations to fall back on.
  bool get isCustom => builtInKey == null;

  /// The user's override for [localeCode], or for any other language if they
  /// have renamed the field but not in this one (§6.1 resolution order).
  String? userLabelFor(String localeCode) =>
      labels[localeCode] ?? (labels.isEmpty ? null : labels.values.first);
}
