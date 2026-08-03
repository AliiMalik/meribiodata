import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'spec.dart';

/// Pipeline B — rasterize the Flutter widget tree, place the bitmap on the page.
///
/// Shaping is done by Flutter/HarfBuzz, so whatever the user saw on screen is
/// what lands in the PDF. Cost: text is not selectable and file size is driven
/// by the capture resolution.
class PipelineB {
  /// 595pt * 4.17 ≈ 2480px = A4 at 300dpi.
  static const captureRatio = 4.17;

  /// Last captured pixel dimensions, so the spike can assert it really got an
  /// A4-at-300dpi bitmap rather than a silently clamped one.
  static String lastCaptureSize = '';

  static Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    double pixelRatio = captureRatio,
  }) async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    if (boundary.size.width.round() != LayoutSpec.pageWidthPt.round() ||
        boundary.size.height.round() != LayoutSpec.pageHeightPt.round()) {
      throw StateError(
        'Boundary laid out at ${boundary.size}, expected '
        '${LayoutSpec.pageWidthPt}x${LayoutSpec.pageHeightPt}',
      );
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    lastCaptureSize = '${image.width}x${image.height}';
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  static Future<Uint8List> build(Uint8List pngBytes) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(pngBytes);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
      ),
    );
    return pdf.save();
  }

  /// Long-edge px for the WhatsApp-tuned image export (see 9.1). Kept here so
  /// the spike also reports what an image export would weigh.
  static const whatsAppLongEdge = 1600;

  static double whatsAppRatio() =>
      whatsAppLongEdge / LayoutSpec.pageHeightPt;
}
