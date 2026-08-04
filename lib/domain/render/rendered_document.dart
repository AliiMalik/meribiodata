import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

/// Which version of the document is being produced (9.4).
///
/// The model supports both from M3 so the M5 export modes need no rework; only
/// [ExportMode.full] is reachable from the UI before M5.
enum ExportMode {
  /// Every visible field, exactly as entered. For serious proposals.
  full,

  /// Sensitive fields omitted, generalised or replaced. For wide circulation.
  shareable,
}

/// One label/value pair, already resolved and formatted.
class RenderedField {
  const RenderedField({
    required this.id,
    required this.label,
    required this.value,
    required this.type,
    this.isSensitive = false,
    this.wasMasked = false,
  });

  final String id;
  final String label;

  /// Display-ready: units applied, digits converted, bidi isolated.
  final String value;

  final FieldType type;
  final bool isSensitive;

  /// True when Shareable mode changed this value. Lets a template mark it, and
  /// lets tests assert masking without re-deriving it.
  final bool wasMasked;
}

class RenderedSection {
  const RenderedSection({required this.title, required this.fields});

  final String title;
  final List<RenderedField> fields;

  bool get isEmpty => fields.isEmpty;
}

/// Everything a template needs, and nothing it does not.
///
/// Templates never see a `BiodataProfile`, a `BiodataSchema` or a
/// `LabelResolver` — which is what makes them able to render *whatever schema
/// exists* (§6.4) and what makes golden tests cheap to write.
class RenderedDocument {
  const RenderedDocument({
    required this.title,
    required this.sections,
    required this.language,
    required this.digitStyle,
    required this.mode,
    this.headerText,
    this.watermark,
  });

  /// The candidate's name, or a fallback. Used as the document heading.
  final String title;

  final List<RenderedSection> sections;
  final LanguageDescriptor language;
  final DigitStyle digitStyle;
  final ExportMode mode;

  /// Optional line printed above everything — a Bismillah, a family name.
  final String? headerText;

  /// Phase 1 footer watermark. Null suppresses it.
  final String? watermark;

  bool get isRtl => language.isRtl;

  /// Sections with at least one field. A section whose fields are all empty or
  /// masked away must not print as a bare heading.
  List<RenderedSection> get nonEmptySections =>
      sections.where((s) => !s.isEmpty).toList();

  int get fieldCount =>
      sections.fold(0, (total, section) => total + section.fields.length);
}
