import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';

part 'biodata_profile.freezed.dart';
part 'biodata_profile.g.dart';

/// One saved biodata.
///
/// Carries its own [schema] (D6) and a flat [values] map keyed by field id.
/// Values are plain JSON — scalars for simple types, objects for structured
/// ones — so a profile serializes straight into storage and into the `.mbd`
/// backup with no second representation.
@freezed
abstract class BiodataProfile with _$BiodataProfile {
  const factory BiodataProfile({
    required String id,
    required BiodataSchema schema,
    required DateTime createdAt,
    required DateTime updatedAt,

    /// Internal label for the profile list. Never printed (§6.2).
    /// Falls back to the candidate's name, then to a placeholder.
    String? profileName,

    /// The language the *document* is generated in — distinct from the app's
    /// UI locale and stored per profile (§5).
    @Default('en') String documentLanguageCode,

    /// Field id → value. Structured types store a JSON object; see
    /// `field_values.dart`.
    @Default(<String, dynamic>{}) Map<String, dynamic> values,

    /// Chosen template id. Null until the user picks one; the renderer falls
    /// back to the default rather than refusing to draw.
    String? templateId,

    /// Chosen page size id (`a4`, `letter`, `card`). Remembered per profile
    /// because a card-sized biodata is a deliberate, repeated choice.

    /// Optional title printed above the biodata — a Bismillah line, a family
    /// name, a Quranic reference (§6.2, optional extras). A document-level
    /// property rather than a schema field, because it renders outside the
    /// section layout and templates would otherwise have to special-case it.
    String? headerText,

    /// Relative path of the candidate photo inside the app's private
    /// directory. Never a content:// URI, which would not survive a restart.
    String? photoPath,

    /// Prints the photo on a page of its own rather than under the name (9.3).
    ///
    /// Two real reasons families ask for this: a photo page can be printed on
    /// photo paper while the details print on plain paper, and when the biodata
    /// is shared as images, the photo is a separate file the sender can simply
    /// not forward.
    @Default(false) bool photoOnSeparatePage,
  }) = _BiodataProfile;

  const BiodataProfile._();

  factory BiodataProfile.fromJson(Map<String, dynamic> json) =>
      _$BiodataProfileFromJson(json);

  Object? valueOf(String fieldId) => values[fieldId];

  bool hasValue(String fieldId) {
    final value = values[fieldId];
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    return true;
  }

  /// Completion across the fields that will actually be printed. Hidden
  /// fields are excluded — counting a field the user deliberately hid against
  /// their progress would be nonsense.
  double get completion {
    final counted = schema.fields.where((f) => f.isVisible).toList();
    if (counted.isEmpty) return 0;
    final filled = counted.where((f) => hasValue(f.id)).length;
    return filled / counted.length;
  }

  /// Required fields still empty. Drives the export-time warning, not a block:
  /// the user is always allowed to export an incomplete biodata.
  List<String> get missingRequiredFieldIds => schema.fields
      .where((f) => f.isVisible && f.isRequired && !hasValue(f.id))
      .map((f) => f.id)
      .toList();
}
