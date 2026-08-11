import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/core/widgets/language_option_tile.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/features/export/widgets/export_mode_selector.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

import 'contrast_test.dart' show contrastRatio;

/// Cover for a bug a user reported: in dark mode several panels were
/// unreadable, their text staying near-white on a near-white fill.
///
/// The cause was a widget pairing a *light palette* fill with text the theme
/// had coloured for the dark background. Every pair in `contrast_test.dart`
/// passed throughout, because that file measures the palette and the defect was
/// in how a widget combined it. `theme_usage_test.dart` now forbids naming a
/// palette constant outside the theme layer, which stops the specific mistake —
/// but a widget can still pair a themed container with the theme's *body* text
/// colour and reproduce it exactly.
///
/// So these render the real widgets, in the real dark theme, and measure what
/// actually comes out.
void main() {
  const aaBody = 4.5;

  final english = AppLanguages.byCode('en');

  Widget wrap(Widget child, {required Brightness brightness}) => MaterialApp(
    theme: brightness == Brightness.dark
        ? AppTheme.darkFor(english)
        : AppTheme.lightFor(english),
    locale: const Locale('en'),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(body: child),
  );

  /// The colour a [Text] will actually paint with, after the theme's default
  /// style has been merged in — which is where the bug lived.
  Color resolvedTextColor(WidgetTester tester, Finder finder) {
    final text = tester.widget<Text>(finder);
    final context = tester.element(finder);
    final style = DefaultTextStyle.of(context).style.merge(text.style);
    final color = style.color;
    expect(color, isNotNull, reason: 'no resolved colour for "${text.data}"');
    return color!;
  }

  Color containerColorOf(WidgetTester tester, Finder textInside) {
    final container = find
        .ancestor(of: textInside, matching: find.byType(Container))
        .first;
    final decoration =
        tester.widget<Container>(container).decoration! as BoxDecoration;
    expect(
      decoration.color,
      isNotNull,
      reason: 'the panel under test has no fill',
    );
    return decoration.color!;
  }

  for (final brightness in Brightness.values) {
    final name = brightness.name;

    group('export mode panel is readable in $name mode', () {
      testWidgets('the Shareable hint', (tester) async {
        await tester.pumpWidget(
          wrap(
            ExportModeSelector(
              mode: ExportMode.shareable,
              maskedFieldCount: 3,
              onChanged: (_) {},
            ),
            brightness: brightness,
          ),
        );

        final l10n = AppL10n.of(
          tester.element(find.byType(ExportModeSelector)),
        );
        final hint = find.text(l10n.exportModeShareableHint);

        final ratio = contrastRatio(
          resolvedTextColor(tester, hint),
          containerColorOf(tester, hint),
        );
        expect(
          ratio,
          greaterThanOrEqualTo(aaBody),
          reason:
              'the Shareable hint is ${ratio.toStringAsFixed(2)}:1 on its own '
              'panel in $name mode',
        );
      });

      testWidgets('the Full warning', (tester) async {
        await tester.pumpWidget(
          wrap(
            ExportModeSelector(
              mode: ExportMode.full,
              maskedFieldCount: 0,
              onChanged: (_) {},
            ),
            brightness: brightness,
          ),
        );

        final l10n = AppL10n.of(
          tester.element(find.byType(ExportModeSelector)),
        );
        final hint = find.text(l10n.exportModeFullHint);

        // This is the panel that tells someone their phone number and address
        // are in the file they are about to send. Unreadable is not cosmetic.
        final ratio = contrastRatio(
          resolvedTextColor(tester, hint),
          containerColorOf(tester, hint),
        );
        expect(
          ratio,
          greaterThanOrEqualTo(aaBody),
          reason:
              'the Full-mode warning is ${ratio.toStringAsFixed(2)}:1 on its '
              'own panel in $name mode',
        );
      });
    });

    testWidgets('a selected language row is readable in $name mode', (
      tester,
    ) async {
      final urdu = AppLanguages.byCode('ur');

      await tester.pumpWidget(
        wrap(
          LanguageOptionTile(
            language: urdu,
            selected: true,
            onTap: () {},
          ),
          brightness: brightness,
        ),
      );

      final title = find.text(urdu.nativeName);
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      final fill = tile.selectedTileColor!;

      final ratio = contrastRatio(resolvedTextColor(tester, title), fill);
      expect(
        ratio,
        greaterThanOrEqualTo(aaBody),
        reason:
            'the selected language name is ${ratio.toStringAsFixed(2)}:1 on '
            'the selected-row fill in $name mode',
      );
    });
  }
}
