import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/domain/render/decorated_templates.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/domain/render/templates.dart';
import 'package:meribiodata/features/export/render/pdf_renderer.dart';

import '../support/document_fixtures.dart';

void main() {
  late BundledLabels labels;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadDocumentFonts();
    labels = await BundledLabels.load();
  });

  group('document text size (#34)', () {
    test('normal returns the very same template', () {
      for (final template in Templates.all) {
        expect(
          identical(template.resized(DocumentTextSize.normal), template),
          isTrue,
          reason: 'the default must allocate nothing',
        );
      }
    });

    test('only text grows — never margins or gaps', () {
      for (final template in Templates.all) {
        final base = template.style;
        for (final size in DocumentTextSize.values) {
          final scaled = template.resized(size).style;

          expect(scaled.titleSize, base.titleSize + size.delta);
          expect(scaled.valueSize, base.valueSize + size.delta);
          expect(scaled.labelSize, base.labelSize + size.delta);
          expect(scaled.sectionTitleSize, base.sectionTitleSize + size.delta);

          // The load-bearing assertion. Every decorated template's margin is
          // measured against its own border artwork, so a text size that moved
          // the margin would push the biodata into the frame. Gaps matter too:
          // the block stream embeds spacer heights, so changing them here
          // would desync spacing from type.
          expect(
            scaled.margin,
            base.margin,
            reason: '${template.id} margin moved — it would breach the border',
          );
          expect(scaled.rowGap, base.rowGap, reason: template.id);
          expect(scaled.sectionGap, base.sectionGap, reason: template.id);
          expect(scaled.labelColumnWidth, base.labelColumnWidth);
        }
      }
    });

    test('the steps stay small enough to stay inside the artwork', () {
      // One point per step. Anything larger and the decorated templates would
      // need their margins re-measured against every border.
      expect(DocumentTextSize.normal.delta, 0);
      expect(DocumentTextSize.large.delta, 1);
      expect(DocumentTextSize.largest.delta, 2);
    });

    test('a resized template is otherwise indistinguishable', () {
      final resized = DecoratedTemplates.filigree.resized(
        DocumentTextSize.largest,
      );

      expect(resized.id, DecoratedTemplates.filigree.id);
      expect(resized.isLocked, DecoratedTemplates.filigree.isLocked);
      expect(resized.category, DecoratedTemplates.filigree.category);
      expect(
        resized.backgroundAsset,
        DecoratedTemplates.filigree.backgroundAsset,
      );

      // Identical gaps mean an identical block stream, which is the reason
      // delegating blocks() to the original is safe.
      final document = sampleDocument('en', labels: labels);
      expect(
        resized.blocks(document).length,
        DecoratedTemplates.filigree.blocks(document).length,
      );
    });

    test('an unknown stored value falls back to normal', () {
      expect(DocumentTextSize.byName('largest'), DocumentTextSize.largest);
      expect(DocumentTextSize.byName('enormous'), DocumentTextSize.normal);
      expect(DocumentTextSize.byName(null), DocumentTextSize.normal);
    });
  });

  group('the PDF backend draws the border artwork', () {
    /// A JPEG embedded in a PDF is compressed with DCTDecode, so its presence
    /// is direct evidence the background reached the file — rather than the
    /// weaker "the call did not throw".
    bool embedsAJpeg(List<int> pdf) {
      const marker = '/DCTDecode';
      final text = String.fromCharCodes(pdf.map((b) => b & 0xFF));
      return text.contains(marker);
    }

    test('a decorated template embeds its background', () async {
      final bytes = await PdfRenderer.vector(
        document: sampleDocument('en', labels: labels),
        template: DecoratedTemplates.filigree,
        page: PageSpec.a4,
      );

      expect(bytes, isNotEmpty);
      expect(
        embedsAJpeg(bytes),
        isTrue,
        reason: 'the border artwork never reached the PDF',
      );
    });

    test('a plain template embeds nothing', () async {
      final bytes = await PdfRenderer.vector(
        document: sampleDocument('en', labels: labels),
        template: Templates.classic,
        page: PageSpec.a4,
      );

      expect(bytes, isNotEmpty);
      // Latin documents with no photo have nothing raster in them at all,
      // which is the whole point of the vector pipeline.
      expect(embedsAJpeg(bytes), isFalse);
    });

    test('a resized template still carries its background', () async {
      final bytes = await PdfRenderer.vector(
        document: sampleDocument('en', labels: labels),
        template: DecoratedTemplates.deco.resized(DocumentTextSize.largest),
        page: PageSpec.a4,
      );

      expect(embedsAJpeg(bytes), isTrue);
    });
  });
}
