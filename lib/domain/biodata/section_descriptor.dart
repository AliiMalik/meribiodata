import 'package:freezed_annotation/freezed_annotation.dart';

part 'section_descriptor.freezed.dart';
part 'section_descriptor.g.dart';

/// A group of fields with a heading. Sections are reorderable, hideable,
/// renameable and user-creatable, exactly like fields.
@freezed
abstract class SectionDescriptor with _$SectionDescriptor {
  const factory SectionDescriptor({
    required String id,
    required int order,

    /// `personal`, `family`, `contact` for the seeded sections; null for
    /// user-created ones.
    String? builtInKey,

    /// User-supplied heading overrides, keyed by locale code. Same layering
    /// rule as `FieldDescriptor.labels`.
    @Default(<String, String>{}) Map<String, String> titles,

    @Default(true) bool isVisible,

    /// The three seeded sections are mandatory (§6.2) — they can be renamed
    /// and reordered, but not removed.
    @Default(true) bool isDeletable,
  }) = _SectionDescriptor;

  const SectionDescriptor._();

  factory SectionDescriptor.fromJson(Map<String, dynamic> json) =>
      _$SectionDescriptorFromJson(json);

  bool get isCustom => builtInKey == null;

  String? userTitleFor(String localeCode) =>
      titles[localeCode] ?? (titles.isEmpty ? null : titles.values.first);
}
