import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:meribiodata/core/platform/platform_bridge.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/features/export/render/document_exporter.dart';
import 'package:meribiodata/features/export/render/pdf_renderer.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// What came out of an export.
class ExportResult {
  const ExportResult({
    required this.files,
    required this.pageCount,
    required this.bytes,
    required this.elapsed,
  });

  final List<File> files;
  final int pageCount;
  final int bytes;
  final Duration elapsed;
}

/// Produces the files the user actually shares.
///
/// Routes between the two backends by script (D1) so callers never choose a
/// pipeline — choosing wrongly is exactly the failure M0 exists to prevent.
class ExportService {
  const ExportService({this.exporter = const DocumentExporter()});

  final DocumentExporter exporter;

  /// WhatsApp downscales anything much above this, so exporting larger comes
  /// back blurrier, not sharper. Tuned properly in M5 (9.1) against a real
  /// round trip; this is the M3 starting point.
  static const shareImageLongEdge = 1600;

  Future<ExportResult> exportPdf({
    required BuildContext context,
    required RenderedDocument document,
    required DocumentTemplate template,
    required PageSpec page,
    required String fileName,
    double dpi = DocumentExporter.printDpi,
  }) async {
    final stopwatch = Stopwatch()..start();

    final Uint8List bytes;
    var pageCount = 1;

    if (document.language.pipeline == RenderPipeline.vector) {
      bytes = await PdfRenderer.vector(
        document: document,
        template: template,
        page: page,
      );
    } else {
      final pages = await exporter.renderPages(
        context: context,
        document: document,
        template: template,
        page: page,
        dpi: dpi,
      );
      pageCount = pages.length;
      bytes = await PdfRenderer.fromRasterPages(pages, page);
    }

    final file = await _write('$fileName.pdf', bytes);
    stopwatch.stop();

    return ExportResult(
      files: [file],
      pageCount: pageCount,
      bytes: bytes.length,
      elapsed: stopwatch.elapsed,
    );
  }

  /// One JPEG per page, numbered so the ordering survives a WhatsApp send.
  Future<ExportResult> exportImages({
    required BuildContext context,
    required RenderedDocument document,
    required DocumentTemplate template,
    required PageSpec page,
    required String fileName,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Images always take the raster path, including for English: an image of
    // vector text would mean rendering the document twice, two ways.
    const longEdge = shareImageLongEdge;
    final dpi = longEdge / (page.height / 72);

    final pages = await exporter.renderPages(
      context: context,
      document: document,
      template: template,
      page: page,
      dpi: dpi,
    );

    final files = <File>[];
    var total = 0;
    for (var i = 0; i < pages.length; i++) {
      // JPEG rather than PNG: M0 showed encoding dominates export time, and
      // JPEG is both far faster and far smaller for a mostly-text page.
      final jpeg = await FlutterImageCompress.compressWithList(
        pages[i].png,
        quality: 90,
      );
      final suffix = pages.length == 1 ? '' : '-${i + 1}';
      files.add(await _write('$fileName$suffix.jpg', jpeg));
      total += jpeg.length;
    }

    stopwatch.stop();
    return ExportResult(
      files: files,
      pageCount: pages.length,
      bytes: total,
      elapsed: stopwatch.elapsed,
    );
  }

  /// Copies every file of [result] into the user's own Downloads or Pictures.
  ///
  /// Returns true only if *all* of them landed. A multi-page biodata that
  /// published three pages of five is not "saved", and telling the user it was
  /// would be worse than telling them it failed.
  Future<bool> publish(
    ExportResult result, {
    required String mimeType,
    PlatformBridge platform = const PlatformBridge(),
  }) async {
    if (result.files.isEmpty) return false;
    for (final file in result.files) {
      final saved = await platform.saveToGallery(
        file: file,
        mimeType: mimeType,
      );
      if (saved == null) return false;
    }
    return true;
  }

  Future<void> share(ExportResult result, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [for (final file in result.files) XFile(file.path)],
        text: text,
      ),
    );
  }

  /// Sends straight to WhatsApp, falling back to the share sheet (9.1).
  ///
  /// Returns true when WhatsApp took it. The fallback is deliberate rather
  /// than an error path: on a phone without WhatsApp the user still expects
  /// the button to do something.
  Future<bool> shareToWhatsApp(
    ExportResult result, {
    required String mimeType,
    String? text,
    PlatformBridge platform = const PlatformBridge(),
  }) async {
    final sent = await platform.shareToWhatsApp(
      files: result.files,
      mimeType: mimeType,
      text: text,
    );
    if (!sent) await share(result, text: text);
    return sent;
  }

  /// Exports live in a dedicated directory so "delete all my data" (NFR-7) can
  /// clear cached exports as well as the database.
  ///
  /// The *support* directory rather than the documents one, because it maps to
  /// Android's `files/` — the only location a FileProvider `<files-path>` can
  /// grant from. Sharing to WhatsApp (9.1) needs that grant, and keeping the
  /// grant to one directory means a share intent can never expose the database
  /// or a stored photo.
  static Future<Directory> exportsDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> _write(String name, Uint8List bytes) async {
    final dir = await exportsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes);
    return file;
  }

  /// A filename that says what the file is. In M5 this also carries the export
  /// mode, so a Full document is never mistaken for a Shareable one (9.4).
  static String fileNameFor(RenderedDocument document) {
    final safe = document.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-');
    final base = safe.isEmpty ? 'Biodata' : safe;
    return document.mode == ExportMode.shareable
        ? '$base-Shareable'
        : '$base-Biodata';
  }
}
