@Tags(['store'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/domain/render/decorated_templates.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/domain/render/templates.dart';
import 'package:meribiodata/features/export/render/block_widgets.dart';

import '../support/document_fixtures.dart';

/// Renders Play Store screenshots of a *complete* biodata, in every script.
///
///     flutter test --tags store test/render/store_screenshots_test.dart
///
/// Not part of the normal suite — it writes files rather than asserting, so it
/// is tagged out and run deliberately.
///
/// Rendered rather than captured from a device on purpose. Typing a full
/// biodata through `adb input text` is slow, breaks on any non-ASCII, and would
/// have to be repeated for Urdu, Sindhi and Pashto — which is exactly the part
/// worth showing. Seeding the data and rendering it uses the same widgets the
/// export does, so these images are the real output, not a mock of it.
const _out = 'docs/brand/store/screenshots/phone';

/// 1080x1920 at devicePixelRatio 3 — Play's promotable size, 9:16.
const _logical = Size(360, 640);
const _pixelRatio = 3.0;

/// The boundary the capture reads from. Added explicitly because a bare widget
/// tree has none, and `toImage` can only be taken from one.
const ValueKey<String> _shot = ValueKey('store-shot');

Future<void> main() async {
  late BundledLabels labels;

  setUpAll(() async {
    await loadDocumentFonts();
    labels = await BundledLabels.load();
  });

  /// One page of a document, framed the way the export screen frames it.
  Widget frame(
    RenderedDocument document,
    DocumentTemplate template,
    Widget? background,
  ) {
    const page = PageSpec.a4;
    return RepaintBoundary(
      key: _shot,
      child: MediaQuery(
        data: const MediaQueryData(
          size: _logical,
          devicePixelRatio: _pixelRatio,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ColoredBox(
            color: const Color(0xFFF4F5F3),
            child: Center(
              // Margin on all four sides so the page reads as a sheet of
              // paper rather than bleeding off the screenshot.
              //
              // No drop shadow. PhysicalModel drew its elevation as a hard
              // black bar across the top edge here — a bare widget tree has no
              // ambient lighting for it to work with — and the page is white
              // on grey, which separates perfectly well without one.
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 26,
                ),
                child: FittedBox(
                  child: DocumentPage(
                    blocks: template.blocks(document),
                    style: template.style,
                    language: document.language,
                    page: page,
                    offsetY: 0,
                    height: page.height - template.style.margin * 2,
                    watermark: document.watermark,
                    background: background,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<Widget?> background(WidgetTester tester, DocumentTemplate t) async {
    final asset = t.backgroundAsset;
    if (asset == null) return null;
    final image = await tester.runAsync(() async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: PageSpec.a4.width.round(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    });
    if (image == null) return null;
    addTearDown(image.dispose);
    return RawImage(image: image, fit: BoxFit.cover);
  }

  Future<void> shoot(WidgetTester tester, String name, Widget child) async {
    tester.view
      ..physicalSize = Size(
        _logical.width * _pixelRatio,
        _logical.height * _pixelRatio,
      )
      ..devicePixelRatio = _pixelRatio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(child);
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_shot),
    );
    // 3x, not the 1.0 default: the boundary is 360x640 logical, and Play
    // wants 1080x1920 to consider a screenshot promotable.
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: _pixelRatio),
    );
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    image!.dispose();

    Directory(_out).createSync(recursive: true);
    File('$_out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    // This file's whole purpose is producing artefacts, so saying where they
    // went is the output, not debug noise.
    // ignore: avoid_print
    print('wrote $_out/$name.png');
  }

  // Each language gets a design that suits it, so the set does not look like
  // one screenshot repeated four times.
  const shots = <(String, String)>[
    ('2-preview', 'en'),
    ('6-urdu', 'ur'),
    ('7-sindhi', 'sd'),
    ('8-pashto', 'ps'),
  ];
  final designs = <String, DocumentTemplate>{
    'en': DecoratedTemplates.filigree,
    'ur': DecoratedTemplates.greenFlower,
    'sd': DecoratedTemplates.deco,
    'ps': Templates.classic,
  };

  for (final (name, language) in shots) {
    testWidgets('$name ($language)', (tester) async {
      final template = designs[language]!;
      await shoot(
        tester,
        name,
        frame(
          sampleDocument(language, labels: labels),
          template,
          await background(tester, template),
        ),
      );
    });
  }
}
