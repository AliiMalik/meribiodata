import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/features/waitlist/waitlist_screen.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  late AppL10n l10n;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    l10n = await AppL10n.delegate.load(const Locale('en'));
  });

  Future<void> pump(
    WidgetTester tester,
    Future<bool> Function(Uri, {LaunchMode mode}) launcher,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightFor(AppLanguages.english),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: [
          for (final l in AppLanguages.uiLocales) Locale(l.code),
        ],
        home: WaitlistScreen(launcher: launcher),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<bool> succeeds(
    Uri url, {
    LaunchMode mode = LaunchMode.platformDefault,
  }) async => true;

  testWidgets('says what it is and that it is not built yet', (tester) async {
    await pump(tester, succeeds);

    expect(find.text(l10n.waitlistTitle), findsOneWidget);
    expect(find.text(l10n.waitlistComingSoon), findsOneWidget);
  });

  testWidgets('discloses what the form asks and where it goes, before the '
      'button (NFR-5)', (tester) async {
    await pump(tester, succeeds);

    expect(find.text(l10n.waitlistWhatWeAsk), findsOneWidget);
    expect(find.text(l10n.waitlistOpensInBrowser), findsOneWidget);

    // The disclosures must sit above the button — a user should know what is
    // being asked before they tap, not after.
    final disclosure = tester.getTopLeft(
      find.text(l10n.waitlistOpensInBrowser),
    );
    final button = tester.getTopLeft(find.text(l10n.waitlistOpenForm));
    expect(disclosure.dy, lessThan(button.dy));
  });

  testWidgets('opens the form externally, not inside the app (D8)', (
    tester,
  ) async {
    Uri? opened;
    LaunchMode? usedMode;
    await pump(tester, (url, {mode = LaunchMode.platformDefault}) async {
      opened = url;
      usedMode = mode;
      return true;
    });

    await tester.tap(find.text(l10n.waitlistOpenForm));
    await tester.pumpAndSettle();

    expect(opened.toString(), WaitlistForm.url);
    // externalApplication: the app must never render the third-party form
    // itself, which is what keeps the data-sharing disclosure narrow.
    expect(usedMode, LaunchMode.externalApplication);
  });

  testWidgets('confirms visibly when the form opens', (tester) async {
    await pump(tester, succeeds);

    await tester.tap(find.text(l10n.waitlistOpenForm));
    await tester.pumpAndSettle();

    expect(find.text(l10n.waitlistOpened), findsOneWidget);
  });

  testWidgets('says so when no browser can open it', (tester) async {
    await pump(
      tester,
      (url, {mode = LaunchMode.platformDefault}) async => false,
    );

    await tester.tap(find.text(l10n.waitlistOpenForm));
    await tester.pumpAndSettle();

    expect(find.text(l10n.waitlistNoBrowser), findsOneWidget);
  });

  testWidgets('degrades to a message when launching throws', (tester) async {
    await pump(
      tester,
      (url, {mode = LaunchMode.platformDefault}) async =>
          throw StateError('no activity found'),
    );

    await tester.tap(find.text(l10n.waitlistOpenForm));
    await tester.pumpAndSettle();

    // §7.8: submission must succeed or fail gracefully with a visible
    // confirmation, and work as a no-op-with-message when offline.
    expect(find.text(l10n.waitlistOffline), findsOneWidget);
  });

  testWidgets('reaches no Phase 2 surface (§0.1)', (tester) async {
    await pump(tester, succeeds);

    // The only interactive control on this screen is the one button. If a CRM
    // entry point is ever added here, this fails.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  test('the form URL is still the placeholder', () {
    // A reminder rather than a failure: open question 8. When the real form
    // exists, this test flips to asserting it is *not* a placeholder.
    expect(
      WaitlistForm.isPlaceholder,
      isTrue,
      reason: 'If this fails, a real form URL has landed — update this test.',
    );
  });
}
