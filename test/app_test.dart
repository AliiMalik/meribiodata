import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/app.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/preferences/preferences_repository.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/features/ads/consent_gate.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

import 'support/fake_consent.dart';
import 'support/in_memory_local_store.dart';

Future<AppPreferences> _preferencesIn(InMemoryLocalStore store) async {
  final preferences = AppPreferences(PreferencesRepository(store));
  await preferences.load();
  return preferences;
}

void main() {
  late InMemoryLocalStore store;
  late BundledLabels labels;
  late ConsentGate consent;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Loads the real asset, so a malformed field_labels.json fails a test
    // rather than only showing up on a device.
    labels = await BundledLabels.load();
  });

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    // Ads stay off in widget tests: the real SDK would make a network call.
    consent = await resolvedGateWithoutAds();
  });

  testWidgets('first run lands on onboarding', (tester) async {
    final preferences = await _preferencesIn(store);

    await tester.pumpWidget(
      MeriBiodataApp(
        store: store,
        preferences: preferences,
        profiles: ProfileRepository(store),
        labels: labels,
        consent: consent,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppL10n.delegate.load(const Locale('en'));
    expect(find.text(l10n.onboardingWelcomeTitle), findsOneWidget);
  });

  testWidgets('a returning user lands on home', (tester) async {
    final preferences = await _preferencesIn(store);
    await preferences.completeOnboarding();

    await tester.pumpWidget(
      MeriBiodataApp(
        store: store,
        preferences: preferences,
        profiles: ProfileRepository(store),
        labels: labels,
        consent: consent,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppL10n.delegate.load(const Locale('en'));
    expect(find.text(l10n.homeEmptyTitle), findsOneWidget);
  });

  testWidgets('switching the UI language re-renders in that language', (
    tester,
  ) async {
    final preferences = await _preferencesIn(store);
    await preferences.completeOnboarding();

    await tester.pumpWidget(
      MeriBiodataApp(
        store: store,
        preferences: preferences,
        profiles: ProfileRepository(store),
        labels: labels,
        consent: consent,
      ),
    );
    await tester.pumpAndSettle();

    await preferences.setUiLanguage(AppLanguages.urdu);
    await tester.pumpAndSettle();

    final urdu = await AppL10n.delegate.load(const Locale('ur'));
    expect(find.text(urdu.homeEmptyTitle), findsOneWidget);
  });

  testWidgets('the app renders right-to-left in an RTL locale', (
    tester,
  ) async {
    final preferences = await _preferencesIn(store);
    await preferences.completeOnboarding();
    await preferences.setUiLanguage(AppLanguages.urdu);

    await tester.pumpWidget(
      MeriBiodataApp(
        store: store,
        preferences: preferences,
        profiles: ProfileRepository(store),
        labels: labels,
        consent: consent,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(Scaffold).first)),
      TextDirection.rtl,
    );
  });
}
