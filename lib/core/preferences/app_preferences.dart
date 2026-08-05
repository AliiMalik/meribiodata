import 'package:flutter/foundation.dart';
import 'package:meribiodata/core/preferences/preferences_repository.dart';
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

  final PreferencesRepository _repository;

  LanguageDescriptor _uiLanguage = AppLanguages.english;
  DigitStyle _digitStyle = DigitStyle.western;
  bool _onboardingComplete = false;
  bool _exportModesExplained = false;
  bool _romanInputDefault = false;

  LanguageDescriptor get uiLanguage => _uiLanguage;
  DigitStyle get digitStyle => _digitStyle;
  bool get onboardingComplete => _onboardingComplete;

  /// Whether the Full vs Shareable explanation has been shown. It is the app's
  /// most valuable idea and users will not discover it on their own (9.4), so
  /// it is shown once — and only once, because a repeating dialog gets
  /// dismissed unread.
  bool get exportModesExplained => _exportModesExplained;

  /// Whether Roman typing starts switched on for Urdu-script fields (9.2).
  ///
  /// Off by default: a user who already has an Urdu keyboard should never be
  /// pushed through a transliterator. Once they turn it on, it is remembered.
  bool get romanInputDefault => _romanInputDefault;

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
    _romanInputDefault = values[_keyRomanInput] as bool? ?? false;

    notifyListeners();
  }

  Future<void> setUiLanguage(LanguageDescriptor language) async {
    if (language.code == _uiLanguage.code) return;
    _uiLanguage = language;
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
  });
}
