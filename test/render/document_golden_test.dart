@Tags(['golden'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/render/doc_block.dart';
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
    Map<Uint8List, ui.Image> images = const {},
  }) async {
    // A4 is the only page size (D18), so this is no longer a parameter.
    const page = PageSpec.a4;

    // Decoded through runAsync and handed in as a RawImage, exactly as
    // DocumentExporter does it. Image.asset would never finish here — widget
    // tests run on fake async, so an asset load simply does not complete, and
    // every one of these goldens would have quietly captured a blank page
    // while appearing to cover the artwork.
    final background = await _background(tester, template, page);

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
            images: images,
            watermark: document.watermark,
            background: background,
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
  });

  group('template x language x export mode (M5 exit criterion)', () {
    // Shareable is the mode most documents will actually be sent in, so it
    // gets the same coverage Full does rather than a single spot check.
    for (final template in Templates.all) {
      for (final language in ['en', 'ur']) {
        testWidgets('${template.id} / $language / shareable', (tester) async {
          await pumpPage(
            tester,
            sampleDocument(
              language,
              labels: labels,
              mode: ExportMode.shareable,
            ),
            template,
          );

          await expectLater(
            find.byType(DocumentPage),
            matchesGoldenFile(
              'goldens/${template.id}-$language-shareable.png',
            ),
          );
        });
      }
    }

    testWidgets('Shareable removes what Full shows', (tester) async {
      final full = sampleDocument('en', labels: labels);
      final shareable = sampleDocument(
        'en',
        labels: labels,
        mode: ExportMode.shareable,
      );

      // The contact number is omitted outright and the address is coarsened,
      // so Shareable must carry strictly fewer fields.
      expect(shareable.fieldCount, lessThan(full.fieldCount));

      final shareableValues = shareable.sections
          .expand((s) => s.fields)
          .map((f) => f.value)
          .join(' ');
      expect(shareableValues, isNot(contains('1234567')));
      expect(shareableValues, isNot(contains('House 12')));
    });
  });

  group('the photo in the document (9.3)', () {
    /// A recognisable test card rather than a flat colour, so a golden would
    /// change if the photo were ever squashed, mirrored or cropped wrongly.
    Future<Uint8List> testCard(int width, int height) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder)
        ..drawRect(
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
          Paint()..color = const Color(0xFFB0BEC5),
        )
        // Off-centre, so a horizontal flip is visible.
        ..drawCircle(
          Offset(width * 0.35, height * 0.3),
          width * 0.18,
          Paint()..color = const Color(0xFF37474F),
        )
        ..drawRect(
          Rect.fromLTWH(0, height * 0.75, width.toDouble(), height * 0.25),
          Paint()..color = const Color(0xFF546E7A),
        );
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      picture.dispose();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    }

    RenderedDocument withPhoto(
      RenderedDocument document,
      Uint8List photo, {
      bool separatePage = false,
    }) => RenderedDocument(
      title: document.title,
      sections: document.sections,
      language: document.language,
      digitStyle: document.digitStyle,
      mode: document.mode,
      headerText: document.headerText,
      watermark: document.watermark,
      photo: photo,
      photoOnSeparatePage: separatePage,
    );

    /// Decodes the way the exporter does. Image.memory would paint a frame or
    /// two late and the golden would capture an empty rectangle.
    Future<Map<Uint8List, ui.Image>> decode(
      WidgetTester tester,
      List<DocBlock> blocks,
    ) async {
      final images = <Uint8List, ui.Image>{};
      for (final block in blocks.whereType<DocPhoto>()) {
        final decoded = await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(block.bytes);
          final frame = await codec.getNextFrame();
          codec.dispose();
          return frame.image;
        });
        images[block.bytes] = decoded!;
      }
      addTearDown(() {
        for (final image in images.values) {
          image.dispose();
        }
      });
      return images;
    }

    for (final template in Templates.all) {
      testWidgets('${template.id} lays out an inline photo', (tester) async {
        final photo = await tester.runAsync(() => testCard(300, 400));
        final document = withPhoto(
          sampleDocument('en', labels: labels),
          photo!,
        );

        await pumpPage(
          tester,
          document,
          template,
          images: await decode(tester, template.blocks(document)),
        );

        await expectLater(
          find.byType(DocumentPage),
          matchesGoldenFile('goldens/${template.id}-photo.png'),
        );
      });
    }

    testWidgets('an RTL document keeps the photo centred, not mirrored', (
      tester,
    ) async {
      final photo = await tester.runAsync(() => testCard(300, 400));
      final document = withPhoto(
        sampleDocument('ur', labels: labels),
        photo!,
      );

      await pumpPage(
        tester,
        document,
        Templates.classic,
        images: await decode(tester, Templates.classic.blocks(document)),
      );

      await expectLater(
        find.byType(DocumentPage),
        matchesGoldenFile('goldens/classic-ur-photo.png'),
      );
    });

    testWidgets('a landscape photo is cropped to portrait, never squashed', (
      tester,
    ) async {
      // The stored photo is portrait, but a restored backup or a future crop
      // shape could hand a wider one over. BoxFit.cover must crop it.
      final photo = await tester.runAsync(() => testCard(600, 300));
      final document = withPhoto(
        sampleDocument('en', labels: labels),
        photo!,
      );

      await pumpPage(
        tester,
        document,
        Templates.classic,
        images: await decode(tester, Templates.classic.blocks(document)),
      );

      await expectLater(
        find.byType(DocumentPage),
        matchesGoldenFile('goldens/classic-photo-landscape.png'),
      );
    });
  });
}

/// The template's border artwork, decoded for real.
Future<Widget?> _background(
  WidgetTester tester,
  DocumentTemplate template,
  PageSpec page,
) async {
  final asset = template.backgroundAsset;
  if (asset == null) return null;

  final image = await tester.runAsync(() async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: page.width.round(),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  });
  if (image == null) return null;

  addTearDown(image.dispose);
  return RawImage(image: image, fit: BoxFit.cover);
}
