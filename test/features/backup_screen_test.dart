import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/core/widgets/text_prompt_dialog.dart';
import 'package:meribiodata/features/backup/backup_screen.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

import '../support/in_memory_local_store.dart';

void main() {
  late AppL10n l10n;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    l10n = await AppL10n.delegate.load(const Locale('en'));
  });

  Future<void> pumpBackup(WidgetTester tester) async {
    final store = InMemoryLocalStore();
    await store.init();

    await tester.pumpWidget(
      Provider<LocalStore>.value(
        value: store,
        child: const MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: [Locale('en')],
          home: BackupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('choosing a backup password (9.5)', () {
    testWidgets('asks for both entries in one dialog', (tester) async {
      await pumpBackup(tester);

      await tester.tap(find.text(l10n.backupCreate));
      await tester.pumpAndSettle();

      // Both fields and the no-recovery warning are visible together, so the
      // user reads the consequence while choosing rather than beforehand.
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.text(l10n.backupNoRecovery), findsWidgets);
    });

    testWidgets('refuses a short password without closing', (tester) async {
      await pumpBackup(tester);
      await tester.tap(find.text(l10n.backupCreate));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'short');
      await tester.enterText(find.byType(TextField).last, 'short');
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.backupPasswordTooShort), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
    });

    testWidgets('refuses a mismatch and keeps what was typed', (tester) async {
      await pumpBackup(tester);
      await tester.tap(find.text(l10n.backupCreate));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'rishta2026');
      await tester.enterText(find.byType(TextField).last, 'rishta2027');
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.backupPasswordMismatch), findsOneWidget);
      // Retyping only the confirmation is enough — the point of one dialog.
      expect(find.text('rishta2026'), findsOneWidget);
    });
  });

  group('promptForText', () {
    // Regression: the controller used to be disposed when showDialog's future
    // completed, which is while the route is still on screen animating out.
    // Opening a second dialog in that same frame tripped an inherited-widget
    // assertion on a device — a long way from the cause.
    testWidgets('survives a second dialog opened the moment it closes', (
      tester,
    ) async {
      String? second;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  await promptForText(context, title: 'First');
                  if (context.mounted) {
                    second = await promptForText(context, title: 'Second');
                  }
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'one');
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect(find.text('Second'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'two');
      await tester.tap(find.text(l10n.actionSave));
      await tester.pumpAndSettle();

      expect(second, 'two');
      expect(tester.takeException(), isNull);
    });
  });
}
