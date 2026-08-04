import 'package:meribiodata/domain/biodata/field_descriptor.dart';
import 'package:meribiodata/domain/biodata/section_descriptor.dart';

/// Supplies the shipped translations for built-in fields and sections.
///
/// Not the app's ARB files: those are keyed to the *UI* locale, and a user
/// running the app in English must still be able to generate an Urdu document
/// (§5). Built-in document labels are therefore a separate, per-document-
/// language lookup — see `BundledLabels`.
abstract interface class BuiltInLabels {
  String? fieldLabel(String builtInKey, String localeCode);

  String? sectionTitle(String builtInKey, String localeCode);
}

/// Resolves the label to show for a field or section in a given language.
///
/// Order (§6.1):
/// 1. the user's override for this language
/// 2. the user's override for any other language
/// 3. the shipped label for this language
/// 4. the shipped English label
/// 5. the raw id
///
/// Step 2 is what makes renaming language-aware: a user who renames "Caste" to
/// "Zaat/Biradari" while writing an Urdu document has *said something* about
/// that field, so an English document should show their words rather than
/// silently reverting — but the Urdu rename must not overwrite a separate
/// English rename.
class LabelResolver {
  const LabelResolver(this._builtIns);

  final BuiltInLabels _builtIns;

  String fieldLabel(FieldDescriptor field, String localeCode) {
    if (field.labels[localeCode] case final String own when own.isNotEmpty) {
      return own;
    }
    if (_anyOverride(field.labels) case final String other) return other;

    final key = field.builtInKey;
    if (key != null) {
      if (_builtIns.fieldLabel(key, localeCode) case final String shipped) {
        return shipped;
      }
      if (_builtIns.fieldLabel(key, _fallbackLocale) case final String en) {
        return en;
      }
    }
    return field.id;
  }

  String sectionTitle(SectionDescriptor section, String localeCode) {
    if (section.titles[localeCode] case final String own when own.isNotEmpty) {
      return own;
    }
    if (_anyOverride(section.titles) case final String other) return other;

    final key = section.builtInKey;
    if (key != null) {
      if (_builtIns.sectionTitle(key, localeCode) case final String shipped) {
        return shipped;
      }
      if (_builtIns.sectionTitle(key, _fallbackLocale) case final String en) {
        return en;
      }
    }
    return section.id;
  }

  /// True when the label shown for [localeCode] comes from another language's
  /// override. The form editor flags this with a language chip so the user can
  /// see *why* their Urdu rename is showing up in the English document (§6.1).
  bool isBorrowedFromAnotherLanguage(
    Map<String, String> overrides,
    String localeCode,
  ) =>
      overrides.isNotEmpty &&
      (overrides[localeCode] == null || overrides[localeCode]!.isEmpty);

  static const _fallbackLocale = 'en';

  /// Deterministic pick so the same schema always renders the same way:
  /// prefer English, then the alphabetically first locale present.
  String? _anyOverride(Map<String, String> overrides) {
    if (overrides.isEmpty) return null;
    if (overrides[_fallbackLocale] case final String en when en.isNotEmpty) {
      return en;
    }
    final codes = overrides.keys.toList()..sort();
    for (final code in codes) {
      final value = overrides[code];
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
