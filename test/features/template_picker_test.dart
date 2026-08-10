import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/preferences/preferences_repository.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/render/templates.dart';
import 'package:meribiodata/features/ads/rewarded_ads.dart';
import 'package:meribiodata/features/premium/entitlements.dart';
import 'package:meribiodata/features/templates/template_picker_screen.dart';
import 'package:meribiodata/features/templates/template_unlocks.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';

import '../support/fake_ads.dart';
import '../support/fake_consent.dart';
import '../support/in_memory_local_store.dart';

/// Regression cover for a bug that only ever appeared in a release build.
///
/// `_select` used to reach the editor controller with
/// `context.read<ProfileEditorController>()`. That provider is created inside
/// the picker's own `build`, so the State's context sits above it and the read
/// threw `ProviderNotFoundException` — which, inside an async tap callback,
/// Flutter reports and swallows. Every tap did nothing at all: no template
/// could be selected, and a locked one never reached the unlock sheet.
///
/// A test that taps a card and asserts the profile changed is the cheapest
/// thing that would have caught it.
void main() {
  late InMemoryLocalStore store;
  late BundledLabels labels;
  late ProfileRepository repository;
  late String profileId;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    labels = await BundledLabels.load();
  });

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    repository = ProfileRepository(store);
    final profile = repository.create(profileName: 'Ayesha');
    await repository.save(profile);
    profileId = profile.id;
  });

  Future<void> pumpPicker(WidgetTester tester) async {
    final preferences = AppPreferences(PreferencesRepository(store));
    await preferences.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProfileRepository>.value(value: repository),
          Provider<BundledLabels>.value(value: labels),
          ChangeNotifierProvider<AppPreferences>.value(value: preferences),
          ChangeNotifierProvider<Entitlements>.value(
            value: freeEntitlements(store),
          ),
          ChangeNotifierProvider<TemplateUnlocks>.value(
            value: TemplateUnlocks(store),
          ),
          Provider<RewardedAds>.value(
            value: RewardedAds(
              consent: await resolvedGateWithoutAds(),
              loader: FakeRewardedLoader(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightFor(AppLanguages.english),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: [
            for (final l in AppLanguages.uiLocales) Locale(l.code),
          ],
          home: TemplatePickerScreen(profileId: profileId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a free template actually selects it', (tester) async {
    await pumpPicker(tester);

    // Any free template other than the default, so a no-op cannot pass.
    final target = Templates.free.firstWhere(
      (t) => t.id != Templates.defaultId,
    );
    expect(
      find.text(target.name),
      findsOneWidget,
      reason: '${target.name} should be on the first screen of the picker',
    );

    // Tapping the card, not the label: the name sits in a fixed-height,
    // clipping box, so its own hit area is not a reliable target.
    await tester.tap(
      find
          .ancestor(of: find.text(target.name), matching: find.byType(InkWell))
          .first,
    );
    await tester.pumpAndSettle();

    // The controller autosaves on a debounce, so the tap's durable effect
    // arrives a moment later. Pumping past it and reading storage asserts the
    // thing that actually matters — the choice survives — rather than a
    // transient widget.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    final saved = await repository.load(profileId);
    expect(
      saved!.templateId,
      target.id,
      reason: 'the tap never reached the editor controller',
    );
  });

  testWidgets('a locked template opens the unlock sheet, not silence', (
    tester,
  ) async {
    await pumpPicker(tester);

    final locked = Templates.all.firstWhere((t) => t.isLocked);
    await tester.scrollUntilVisible(
      find.text(locked.name),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(locked.name));
    await tester.pumpAndSettle();

    final l10n = await AppL10n.delegate.load(const Locale('en'));
    // The sheet has to appear. Ads are off in this test, so only the Premium
    // door is offered — but something must be offered.
    expect(find.text(l10n.templateUnlockPremium), findsWidgets);

    // And nothing is selected until the unlock actually succeeds.
    final saved = await repository.load(profileId);
    expect(saved!.templateId, isNot(locked.id));
  });
}
