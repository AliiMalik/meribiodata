import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:meribiodata/domain/render/doc_block.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/features/export/render/block_widgets.dart';
import 'package:meribiodata/features/export/render/paginator.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

/// Raster output for one page.
class RenderedPage {
  const RenderedPage({
    required this.png,
    required this.widthPx,
    required this.heightPx,
  });

  final Uint8List png;
  final int widthPx;
  final int heightPx;
}

/// Rasterizes a document to page images (Pipeline B, D1).
///
/// Runs entirely off-screen: the measuring column and each page are mounted in
/// an overlay far outside the viewport, so nothing flashes on screen while an
/// export is running.
class DocumentExporter {
  const DocumentExporter();

  /// A4 at 300 dpi is 595pt x 4.17. M0 measured the whole cost curve: it is
  /// linear in pixel count and dominated by PNG encoding, so 200 dpi is the
  /// shipping default and 300 is offered for print.
  static const printDpi = 300.0;
  static const screenDpi = 200.0;

  static double ratioForDpi(double dpi) => dpi / 72.0;

  /// Renders every page of [document] with [template].
  ///
  /// Needs an [Overlay] in scope — pass a context from inside a [Navigator].
  Future<List<RenderedPage>> renderPages({
    required BuildContext context,
    required RenderedDocument document,
    required DocumentTemplate template,
    required PageSpec page,
    double dpi = screenDpi,
  }) async {
    final blocks = template.blocks(document);
    final style = template.style;
    final overlay = Overlay.of(context, rootOverlay: true);

    // Decoded before the stage is mounted, never during it. Image.memory
    // decodes asynchronously and paints a frame or two late, which is
    // invisible on screen and produces a blank rectangle in a captured page.
    final images = await _decodePhotos(blocks);
    // Same reasoning as the photos above, and it matters more here: a late
    // background decode loses the border on every page of the export rather
    // than one rectangle on one page.
    final background = await _decodeBackground(template, page, dpi);

    final job = _ExportJob(
      blocks: blocks,
      style: style,
      language: document.language,
      page: page,
      pixelRatio: ratioForDpi(dpi),
      images: images,
      watermark: document.watermark,
      background: background == null
          ? null
          : RawImage(image: background, fit: BoxFit.cover),
    );

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        // Off-screen, but genuinely laid out and painted — which is what makes
        // the measured heights match what is captured.
        left: -100000,
        top: 0,
        child: _ExportStage(job: job),
      ),
    );

    overlay.insert(entry);
    try {
      return await job.completer.future;
    } finally {
      entry.remove();
      for (final image in images.values) {
        image.dispose();
      }
      background?.dispose();
    }
  }

  /// Decodes the template's artwork at the size this export will draw it.
  ///
  /// `targetWidth` rather than the file's own 1654px: an export at screen dpi
  /// needs a fraction of that, and a full decode is ~15 MB of bitmap on a phone
  /// this app promises to run on with 3 GB (NFR-2).
  static Future<ui.Image?> _decodeBackground(
    DocumentTemplate template,
    PageSpec page,
    double dpi,
  ) async {
    final asset = template.backgroundAsset;
    if (asset == null) return null;

    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: (page.width * ratioForDpi(dpi)).round(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } on Object catch (error) {
      // A missing asset must not fail the export. The page renders plain,
      // which is exactly what every template did before backgrounds existed.
      debugPrint('Template background $asset failed to decode: $error');
      return null;
    }
  }

  static Future<Map<Uint8List, ui.Image>> _decodePhotos(
    List<DocBlock> blocks,
  ) async {
    final images = <Uint8List, ui.Image>{};
    for (final block in blocks) {
      if (block is! DocPhoto || images.containsKey(block.bytes)) continue;
      final codec = await ui.instantiateImageCodec(block.bytes);
      images[block.bytes] = (await codec.getNextFrame()).image;
      codec.dispose();
    }
    return images;
  }
}

/// The state machine the off-screen stage walks through.
enum _Phase { measuring, rendering, done }

class _ExportJob {
  _ExportJob({
    required this.blocks,
    required this.style,
    required this.language,
    required this.page,
    required this.pixelRatio,
    required this.images,
    required this.watermark,
    required this.background,
  }) : blockKeys = List.generate(blocks.length, (_) => GlobalKey());

  final List<DocBlock> blocks;
  final TemplateStyle style;
  final LanguageDescriptor language;
  final PageSpec page;
  final double pixelRatio;
  final Map<Uint8List, ui.Image> images;
  final String? watermark;
  final Widget? background;

  final List<GlobalKey> blockKeys;
  final Completer<List<RenderedPage>> completer = Completer();

  List<PageSlice> slices = const [];
}

class _ExportStage extends StatefulWidget {
  const _ExportStage({required this.job});

  final _ExportJob job;

  @override
  State<_ExportStage> createState() => _ExportStageState();
}

class _ExportStageState extends State<_ExportStage> {
  final GlobalKey _pageKey = GlobalKey();

  _Phase _phase = _Phase.measuring;
  int _pageIndex = 0;
  final _pages = <RenderedPage>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_run()));
  }

  Future<void> _run() async {
    final job = widget.job;
    try {
      await _settle();

      final heights = <double>[];
      for (final key in job.blockKeys) {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        heights.add(box?.size.height ?? 0);
      }

      job.slices = Paginator.paginate(
        blocks: job.blocks,
        heights: heights,
        pageHeight: Paginator.contentHeight(job.page, job.style),
      );

      setState(() => _phase = _Phase.rendering);

      for (var i = 0; i < job.slices.length; i++) {
        setState(() => _pageIndex = i);
        await _settle();
        _pages.add(await _capture());
      }

      if (!job.completer.isCompleted) job.completer.complete(_pages);
    } on Object catch (error, stack) {
      if (!job.completer.isCompleted) {
        job.completer.completeError(error, stack);
      }
    } finally {
      if (mounted) setState(() => _phase = _Phase.done);
    }
  }

  /// Two frames plus a microtask gap: the first lays out, the second gives
  /// font resolution and the raster cache a chance to settle. Capturing on the
  /// first frame produced blank pages on a cold start.
  Future<void> _settle() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
  }

  Future<RenderedPage> _capture() async {
    final job = widget.job;
    final boundary =
        _pageKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

    // The M0 harness bug: a SizedBox silently clamps to its parent's
    // constraints, so the page can lay out at the wrong size and be upscaled
    // into a blurry export. Assert rather than trust.
    if ((boundary.size.width - job.page.width).abs() > 0.5 ||
        (boundary.size.height - job.page.height).abs() > 0.5) {
      throw StateError(
        'Page laid out at ${boundary.size}, expected '
        '${job.page.width}x${job.page.height}',
      );
    }

    final image = await boundary.toImage(pixelRatio: job.pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final result = RenderedPage(
      png: data!.buffer.asUint8List(),
      widthPx: image.width,
      heightPx: image.height,
    );
    image.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        // Pin the text scale: an export must not change size because the user
        // enlarged their system font.
        data: const MediaQueryData(),
        child: switch (_phase) {
          _Phase.measuring => Material(
            color: Colors.white,
            child: DocumentColumn(
              blocks: job.blocks,
              style: job.style,
              language: job.language,
              width: job.page.width - job.style.margin * 2,
              blockKeys: job.blockKeys,
              images: job.images,
            ),
          ),
          _Phase.rendering => RepaintBoundary(
            key: _pageKey,
            child: Material(
              color: Colors.white,
              child: DocumentPage(
                blocks: job.blocks,
                style: job.style,
                language: job.language,
                page: job.page,
                offsetY: job.slices[_pageIndex].offsetY,
                height: job.slices[_pageIndex].height,
                images: job.images,
                watermark: job.watermark,
                background: job.background,
              ),
            ),
          ),
          _Phase.done => const SizedBox.shrink(),
        },
      ),
    );
  }
}
