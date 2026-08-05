import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/preferences/preferences_repository.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/features/ads/consent_gate.dart';
import 'package:meribiodata/features/editor/editor_screen.dart';
import 'package:meribiodata/features/home/profile_list_controller.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';

import '../support/fake_consent.dart';
import '../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late ProfileRepository repository;
  late BundledLabels labels;
  late AppL10n l10n;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    labels = await BundledLabels.load();
    l10n = await AppL10n.delegate.load(const Locale('en'));
  });

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    repository = ProfileRepository(store);
  });

  Future<String> seedProfile({String languageCode = 'en'}) async {
    final profile = repository.create(documentLanguageCode: languageCode);
    await repository.save(profile);
    return profile.id;
  }

  Future<void> pumpEditor(WidgetTester tester, String profileId) async {
    final preferences = AppPreferences(PreferencesRepository(store));
    await preferences.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProfileRepository>.value(value: repository),
          Provider<BundledLabels>.value(value: labels),
          ChangeNotifierProvider<AppPreferences>.value(value: preferences),
          // The editor now carries a banner slot, which reads the gate. A
          // resolved gate that refuses ads keeps the SDK out of unit tests.
          ChangeNotifierProvider<ConsentGate>.value(
            value: await resolvedGateWithoutAds(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightFor(AppLanguages.english),
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: [
            for (final l in AppLanguages.uiLocales) Locale(l.code),
          ],
          home: EditorScreen(profileId: profileId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the seeded sections and fields', (tester) async {
    await pumpEditor(tester, await seedProfile());

    expect(find.text('Personal Details'), findsOneWidget);
    expect(find.text('Name'), findsWidgets);

    // The list builds lazily, so the later sections have to be scrolled to.
    for (final heading in ['Family Details', 'Contact & Address']) {
      await tester.scrollUntilVisible(
        find.text(heading),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(heading), findsOneWidget);
    }
  });

  testWidgets('renders the document language, not the UI language', (
    tester,
  ) async {
    await pumpEditor(tester, await seedProfile(languageCode: 'ur'));

    // App chrome stays English; the field labels follow the document.
    expect(find.text(l10n.editorTitle), findsOneWidget);
    expect(find.text('ذاتی معلومات'), findsOneWidget);
    expect(find.text('نام'), findsWidgets);
  });

  testWidgets('sensitive fields are flagged at a glance (9.4)', (tester) async {
    await pumpEditor(tester, await seedProfile());

    // Date of Birth, Maslak and Income are sensitive by default and all sit in
    // the first section.
    expect(find.text(l10n.fieldSensitive), findsWidgets);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
  });

  testWidgets('typing a value autosaves it', (tester) async {
    final id = await seedProfile();
    await pumpEditor(tester, id);

    // Index 0 is the profile-name box; index 1 is the first schema field.
    await tester.enterText(find.byType(TextField).at(1), 'Muhammad Ali');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final saved = await repository.load(id);
    final nameId = saved!.schema.fieldByBuiltInKey(BuiltInKeys.name)!.id;
    expect(saved.values[nameId], 'Muhammad Ali');
  });

  testWidgets('progress reflects what has been filled in', (tester) async {
    final id = await seedProfile();
    await pumpEditor(tester, id);

    expect(find.text(l10n.editorProgress(0)), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'Ali');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text(l10n.editorProgress(0)), findsNothing);
  });

  testWidgets('a missing profile says so rather than showing a blank form', (
    tester,
  ) async {
    await pumpEditor(tester, 'does-not-exist');

    expect(find.text(l10n.editorNotFound), findsOneWidget);
  });

  group('the list reflects edits made in the editor', () {
    // Regression: the Home list held its first load forever, so returning from
    // the editor still showed "Untitled biodata / 0% complete" after the form
    // had been filled in.
    test('reloading picks up an autosaved edit', () async {
      final controller = ProfileListController(repository);
      final profile = await controller.createProfile();
      final nameId = profile.schema.fieldByBuiltInKey(BuiltInKeys.name)!.id;

      expect(controller.visible.single.completion, 0);

      await repository.save(profile.copyWith(values: {nameId: 'Ali'}));
      await controller.load();

      expect(controller.visible.single.completion, greaterThan(0));
      expect(
        profileDisplayName(controller.visible.single, 'Untitled'),
        'Ali',
      );
      controller.dispose();
    });
  });
}
