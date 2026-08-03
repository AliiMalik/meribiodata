import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/preferences/preferences_repository.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

import '../../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late AppPreferences preferences;

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    preferences = AppPreferences(PreferencesRepository(store));
  });

  test('defaults to English, Western digits, onboarding not done', () async {
    await preferences.load();

    expect(preferences.uiLanguage.code, 'en');
    expect(preferences.digitStyle, DigitStyle.western);
    expect(preferences.onboardingComplete, isFalse);
  });

  test('survives a restart', () async {
    await preferences.load();
    await preferences.setUiLanguage(AppLanguages.urdu);
    await preferences.setDigitStyle(DigitStyle.easternArabic);
    await preferences.completeOnboarding();

    final reloaded = AppPreferences(PreferencesRepository(store));
    await reloaded.load();

    expect(reloaded.uiLanguage.code, 'ur');
    expect(reloaded.digitStyle, DigitStyle.easternArabic);
    expect(reloaded.onboardingComplete, isTrue);
  });

  test('notifies once per real change and not for no-ops', () async {
    await preferences.load();
    var notifications = 0;
    preferences.addListener(() => notifications++);

    await preferences.setUiLanguage(AppLanguages.urdu);
    await preferences.setUiLanguage(AppLanguages.urdu);

    expect(notifications, 1);
  });

  test('falls back to English if a stored locale no longer exists', () async {
    await store.put('preferences', 'app', {'uiLocale': 'klingon'});

    await preferences.load();

    expect(preferences.uiLanguage.code, 'en');
  });
}
