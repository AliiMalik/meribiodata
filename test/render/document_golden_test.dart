import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/domain/render/templates.dart';
import 'package:meribiodata/features/export/render/block_widgets.dart';

import '../support/document_fixtures.dart';

/// Golden tests per template x script (M3 exit criterion).
///
/// Script rendering regressions are invisible to anyone who cannot read
/// Nastaliq, so they have to be caught by CI rather than by eye — which is the
/// whole reason these exist.
///
/// Regenerate with: flutter test --update-goldens
void main() {
  late BundledLabels labels;

  setUpAll(() async {
    await loadDocumentFonts();
    labels = await BundledLabels.load();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    RenderedDocument document,
    DocumentTemplate template, {
    PageSpec page = PageSpec.a4,
  }) async {
    tester.view
      ..physicalSize = Size(page.width, page.height)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: DocumentPage(
            blocks: template.blocks(document),
            style: template.style,
            language: document.language,
            page: page,
            offsetY: 0,
            height: page.height - template.style.margin * 2,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('every template renders every P0/P1 script', () {
    // Punjabi shares the Nastaliq path with Urdu, so Urdu covers it; Sindhi
    // and Pashto are the Naskh cases with the extended letters.
    const languages = ['en', 'ur', 'sd', 'ps'];

    for (final template in Templates.all) {
      for (final language in languages) {
        testWidgets('${template.id} / $language', (tester) async {
          await pumpPage(
            tester,
            sampleDocument(language, labels: labels),
            template,
          );

          await expectLater(
            find.byType(DocumentPage),
            matchesGoldenFile('goldens/${template.id}-$language.png'),
          );
        });
      }
    }
  });

  group('layouts that templates must survive (§6.4)', () {
    testWidgets('a nearly empty document does not collapse', (tester) async {
      final document = sampleDocument('en', labels: labels);
      final sparse = RenderedDocument(
        title: document.title,
        sections: const [],
        language: document.language,
        digitStyle: document.digitStyle,
        mode: ExportMode.full,
        watermark: document.watermark,
      );

      await pumpPage(tester, sparse, Templates.classic);

      await expectLater(
        find.byType(DocumentPage),
        matchesGoldenFile('goldens/edge-empty.png'),
      );
    });

    testWidgets('a very long custom label wraps instead of overflowing', (
      tester,
    ) async {
      final document = sampleDocument('en', labels: labels);
      final stressed = RenderedDocument(
        title: document.title,
        sections: [
          const RenderedSection(
            title: 'A Section Whose Title Is Also Unreasonably Long Indeed',
            fields: [
              RenderedField(
                id: 'long',
                // The §6.3 cap is 60 characters; this is exactly that.
                label: 'Grandfather-on-the-mothers-side occupation and city',
                value: 'Retired schoolteacher, Faisalabad',
                type: FieldType.text,
              ),
            ],
          ),
        ],
        language: document.language,
        digitStyle: document.digitStyle,
        mode: ExportMode.full,
      );

      await pumpPage(tester, stressed, Templates.classic);

      await expectLater(
        find.byType(DocumentPage),
        matchesGoldenFile('goldens/edge-long-label.png'),
      );
    });

    testWidgets('the card page size still reads', (tester) async {
      await pumpPage(
        tester,
        sampleDocument('ur', labels: labels),
        Templates.compact,
        page: PageSpec.card,
      );

      await expectLater(
        find.byType(DocumentPage),
        matchesGoldenFile('goldens/card-ur.png'),
      );
    });
  });

  testWidgets('Shareable mode visibly differs from Full (9.4)', (tester) async {
    await pumpPage(
      tester,
      sampleDocument('en', labels: labels, mode: ExportMode.shareable),
      Templates.classic,
    );

    await expectLater(
      find.byType(DocumentPage),
      matchesGoldenFile('goldens/classic-en-shareable.png'),
    );
  });
}
