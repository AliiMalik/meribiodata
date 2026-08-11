import 'package:flutter/material.dart';
import 'package:meribiodata/core/preferences/preferences_repository.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/render/document_builder.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

/// App-wide user preferences.
///
/// Holds only settings that affect the whole app. Anything scoped to a single
/// biodata — document language, template, export mode — belongs on the profile,
/// not here (§5: UI locale and document language are separate concerns).
class AppPreferences extends ChangeNotifier {
  AppPreferences(this._repository);

  static const _keyUiLocale = 'uiLocale';
  static const _keyDigitStyle = 'digitStyle';
  static const _keyOnboardingComplete = 'onboardingComplete';
  static const _keyExportModesExplained = 'exportModesExplained';
  static const _keyRomanInput = 'romanInputDefault';
  static const _keyHeightUnit = 'heightUnit';
  static const _keyWeightUnit = 'weightUnit';
  static const _keyThemeMode = 'themeMode';
  static const _keyDocumentTextSize = 'documentTextSize';

  final PreferencesRepository _repository;

  LanguageDescriptor _uiLanguage = AppLanguages.english;
  DigitStyle _digitStyle = DigitStyle.western;
  bool _onboardingComplete = false;
  bool _exportModesExplained = false;
  bool _romanInputDefault = true;
  LengthUnit _heightUnit = LengthUnit.feetInches;
  MassUnit _weightUnit = MassUnit.kilograms;
  ThemeMode _themeMode = ThemeMode.system;
  DocumentTextSize _documentTextSize = DocumentTextSize.normal;

  LanguageDescriptor get uiLanguage => _uiLanguage;
  DigitStyle get digitStyle => _digitStyle;
  bool get onboardingComplete => _onboardingComplete;

  /// How large the biodata's own text is (#34).
  ///
  /// Remembered rather than reset per export: someone who needs larger type
  /// needs it every time, and making them reset it on each biodata would be a
  /// small cruelty aimed at exactly the users it exists for.
  DocumentTextSize get documentTextSize => _documentTextSize;

  /// Whether the Full vs Shareable explanation has been shown. It is the app's
  /// most valuable idea and users will not discover it on their own (9.4), so
  /// it is shown once — and only once, because a repeating dialog gets
  /// dismissed unread.
  bool get exportModesExplained => _exportModesExplained;

  /// Whether Roman typing starts switched on for Urdu-script fields (9.2).
  ///
  /// **On** by default, reversing the original choice. That choice — don't push
  /// a transliterator on someone with an Urdu keyboard — was sound in the
  /// abstract and wrong in practice: a user made an Urdu biodata and every free
  /// text field came out in English, because the one feature that would have
  /// helped was a toggle buried in Settings that nobody finds.
  ///
  /// Nothing is forced. The field only ever *offers* a conversion for the word
  /// behind the caret, and only when the user taps it, so hand-typed Urdu is
  /// untouched. It appears solely on Perso-Arabic document languages
  /// (`RomanUrduField.isOfferedFor`), so an English biodata never sees it. And
  /// turning it off is still remembered.
  bool get romanInputDefault => _romanInputDefault;

  /// Feet-and-inches by default, because that is how height is spoken about in
  /// Pakistan even where everything else is metric.
  LengthUnit get heightUnit => _heightUnit;

  MassUnit get weightUnit => _weightUnit;

  /// Units as the document builder wants them.
  DocumentUnits get documentUnits =>
      DocumentUnits(length: _heightUnit, mass: _weightUnit);

  /// Follows the phone by default. The *document* is unaffected either way —
  /// a biodata always renders on white paper, because it is printed and
  /// forwarded, not read in the app.
  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final values = await _repository.load();

    if (values[_keyUiLocale] case final String code) {
      _uiLanguage = AppLanguages.byCode(code);
    }
    if (values[_keyDigitStyle] case final String name) {
      _digitStyle = DigitStyle.values.firstWhere(
        (d) => d.name == name,
        orElse: () => DigitStyle.western,
      );
    }
    _onboardingComplete = values[_keyOnboardingComplete] as bool? ?? false;
    _exportModesExplained = values[_keyExportModesExplained] as bool? ?? false;
    _romanInputDefault = values[_keyRomanInput] as bool? ?? true;

    if (values[_keyHeightUnit] case final String wire) {
      _heightUnit = LengthUnit.values.firstWhere(
        (u) => u.wire == wire,
        orElse: () => LengthUnit.feetInches,
      );
    }
    if (values[_keyWeightUnit] case final String wire) {
      _weightUnit = MassUnit.values.firstWhere(
        (u) => u.wire == wire,
        orElse: () => MassUnit.kilograms,
      );
    }
    _documentTextSize = DocumentTextSize.byName(
      values[_keyDocumentTextSize] as String?,
    );
    if (values[_keyThemeMode] case final String name) {
      _themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => ThemeMode.system,
      );
    }

    notifyListeners();
  }

  Future<void> setUiLanguage(LanguageDescriptor language) async {
    if (language.code == _uiLanguage.code) return;
    _uiLanguage = language;
    notifyListeners();
    await _persist();
  }

  Future<void> setHeightUnit(LengthUnit unit) async {
    if (unit == _heightUnit) return;
    _heightUnit = unit;
    notifyListeners();
    await _persist();
  }

  Future<void> setWeightUnit(MassUnit unit) async {
    if (unit == _weightUnit) return;
    _weightUnit = unit;
    notifyListeners();
    await _persist();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _persist();
  }

  Future<void> setDigitStyle(DigitStyle style) async {
    if (style == _digitStyle) return;
    _digitStyle = style;
    notifyListeners();
    await _persist();
  }

  Future<void> completeOnboarding() async {
    if (_onboardingComplete) return;
    _onboardingComplete = true;
    notifyListeners();
    await _persist();
  }

  Future<void> setDocumentTextSize(DocumentTextSize size) async {
    if (_documentTextSize == size) return;
    _documentTextSize = size;
    notifyListeners();
    await _persist();
  }

  Future<void> markExportModesExplained() async {
    if (_exportModesExplained) return;
    _exportModesExplained = true;
    notifyListeners();
    await _persist();
  }

  Future<void> setRomanInputDefault({required bool enabled}) async {
    if (enabled == _romanInputDefault) return;
    _romanInputDefault = enabled;
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() => _repository.save({
    _keyUiLocale: _uiLanguage.code,
    _keyDigitStyle: _digitStyle.name,
    _keyOnboardingComplete: _onboardingComplete,
    _keyExportModesExplained: _exportModesExplained,
    _keyRomanInput: _romanInputDefault,
    _keyHeightUnit: _heightUnit.wire,
    _keyWeightUnit: _weightUnit.wire,
    _keyThemeMode: _themeMode.name,
    _keyDocumentTextSize: _documentTextSize.name,
  });
}
