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
/// Order (§6.1, as ruled in D7):
/// 1. the user's override for this language
/// 2. the shipped label for this language
/// 3. the user's override for any other language
/// 4. the shipped English label
/// 5. the raw id
///
/// Steps 2 and 3 are the D7 ruling, and they are the other way round from how
/// §6.1 first stated the order. Borrowing another language's rename is right
/// for a **custom** field — there is no shipped label, so the alternative is
/// showing a UUID — but wrong for a **built-in** one, where a correct, reviewed
/// translation already exists. Under the original order, renaming "Caste" to
/// "ذات / برادری" in the Urdu document put those Urdu words into the English
/// document, and the blemish landed in the exported PDF: the artifact the
/// family actually shares. A built-in field now keeps its own language's
/// shipped label, and only falls through to another language's rename when it
/// has none.
///
/// Renames remain stored per language throughout; one never overwrites another.
class LabelResolver {
  const LabelResolver(this._builtIns);

  final BuiltInLabels _builtIns;

  String fieldLabel(FieldDescriptor field, String localeCode) {
    if (_own(field.labels, localeCode) case final String own) return own;

    final key = field.builtInKey;
    if (key != null) {
      if (_builtIns.fieldLabel(key, localeCode) case final String shipped) {
        return shipped;
      }
    }
    if (_anyOverride(field.labels) case final String other) return other;
    if (key != null) {
      if (_builtIns.fieldLabel(key, _fallbackLocale) case final String en) {
        return en;
      }
    }
    return field.id;
  }

  String sectionTitle(SectionDescriptor section, String localeCode) {
    if (_own(section.titles, localeCode) case final String own) return own;

    final key = section.builtInKey;
    if (key != null) {
      if (_builtIns.sectionTitle(key, localeCode) case final String shipped) {
        return shipped;
      }
    }
    if (_anyOverride(section.titles) case final String other) return other;
    if (key != null) {
      if (_builtIns.sectionTitle(key, _fallbackLocale) case final String en) {
        return en;
      }
    }
    return section.id;
  }

  /// True when the label shown for [localeCode] came from another language's
  /// override. The form editor flags this with a language chip so the user can
  /// see *why* their Urdu rename is showing up in the English document (§6.1).
  ///
  /// This has to ask the same questions as [fieldLabel] in the same order: a
  /// built-in field with a shipped translation for [localeCode] is now showing
  /// that translation, not a borrowed rename, and flagging it would be a lie.
  bool isFieldLabelBorrowed(FieldDescriptor field, String localeCode) {
    if (_own(field.labels, localeCode) != null) return false;
    final key = field.builtInKey;
    if (key != null && _builtIns.fieldLabel(key, localeCode) != null) {
      return false;
    }
    return _anyOverride(field.labels) != null;
  }

  /// The section counterpart of [isFieldLabelBorrowed].
  bool isSectionTitleBorrowed(SectionDescriptor section, String localeCode) {
    if (_own(section.titles, localeCode) != null) return false;
    final key = section.builtInKey;
    if (key != null && _builtIns.sectionTitle(key, localeCode) != null) {
      return false;
    }
    return _anyOverride(section.titles) != null;
  }

  static const _fallbackLocale = 'en';

  /// An override belonging to [localeCode] itself. Empty is treated as absent:
  /// clearing a rename must fall back, not blank the label out.
  String? _own(Map<String, String> overrides, String localeCode) {
    final value = overrides[localeCode];
    return (value != null && value.isNotEmpty) ? value : null;
  }

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
