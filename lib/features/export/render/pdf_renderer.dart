import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;
import 'package:meribiodata/domain/render/doc_block.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/features/export/render/block_widgets.dart';
import 'package:meribiodata/features/export/render/document_exporter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Assembles the final PDF from whichever backend produced the pages.
abstract final class PdfRenderer {
  /// Pipeline B: page bitmaps placed full-bleed.
  ///
  /// Text is not selectable, which is the price of correct Nastaliq — see
  /// `docs/spike-nastaliq.md`.
  static Future<Uint8List> fromRasterPages(
    List<RenderedPage> pages,
    PageSpec page,
  ) async {
    final document = pw.Document();
    final format = PdfPageFormat(page.width, page.height);

    for (final rendered in pages) {
      final image = pw.MemoryImage(rendered.png);
      document.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (context) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    }

    return document.save();
  }

  /// Pipeline A: real vector text.
  ///
  /// Only ever used for Latin documents (D1). On Perso-Arabic it produces
  /// collapsed glyph piles, tofu and reversed digits — M0 measured exactly how
  /// badly — so `ExportService` routes by script rather than offering this as
  /// a choice.
  static Future<Uint8List> vector({
    required RenderedDocument document,
    required DocumentTemplate template,
    required PageSpec page,
  }) async {
    final style = template.style;
    final contentWidth = page.width - style.margin * 2;
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Inter-Bold.ttf'),
    );

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pw.Widget draw(DocBlock block) => switch (block) {
      DocHeader(:final text) => pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: style.valueSize + 1,
            color: _pdf(style.accent ?? style.mutedInk),
          ),
        ),
      ),
      DocTitle(:final text) =>
        style.titleCentred
            ? pw.Center(child: pw.Text(text, style: _title(bold, style)))
            : pw.Text(text, style: _title(bold, style)),
      DocSectionTitle(:final text) => pw.Text(
        text,
        style: pw.TextStyle(
          font: bold,
          fontSize: style.sectionTitleSize,
          color: _pdf(style.accent ?? style.ink),
        ),
      ),
      DocRow(:final label, :final value) => pw.Padding(
        padding: pw.EdgeInsets.only(bottom: style.rowGap),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: style.labelColumnWidth,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  font: bold,
                  fontSize: style.labelSize,
                  color: _pdf(style.mutedInk),
                ),
              ),
            ),
            pw.SizedBox(width: style.rowGap),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: style.valueSize,
                  color: _pdf(style.ink),
                ),
              ),
            ),
          ],
        ),
      ),
      DocParagraph(:final text) => pw.Text(
        text,
        style: pw.TextStyle(fontSize: style.valueSize, color: _pdf(style.ink)),
      ),
      DocDivider(:final thickness, :final color) => pw.Divider(
        thickness: thickness,
        color: _pdf(color ?? style.rule),
        height: thickness,
      ),
      DocSpacer(:final height) => pw.SizedBox(height: height),
      DocPhoto(:final bytes, :final widthFraction, :final aspectRatio) =>
        pw.Center(
          child: pw.SizedBox(
            width: contentWidth * widthFraction,
            height: contentWidth * widthFraction / aspectRatio,
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
          ),
        ),
      // MultiPage understands this directly; the raster path has to paginate
      // around it itself (see Paginator).
      DocPageBreak() => pw.NewPage(),
    };

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.all(style.margin),
          theme: pw.ThemeData.withFont(base: regular, bold: bold),
          // The watermark is drawn behind the content on every page, matching
          // the raster backend's DocumentWatermark. Deliberately a page
          // background rather than a block: it repeats on every page, costs
          // pagination nothing, and — the point of it — cannot be cropped off
          // the way a footer line can.
          buildBackground: (context) => _watermark(
            document.watermark,
            style,
            page,
            bold,
          ),
        ),
        // MultiPage paginates for free here — the raster path has to do it
        // itself, which is why Paginator exists.
        build: (context) => [
          for (final block in template.blocks(document)) draw(block),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _watermark(
    String? text,
    TemplateStyle style,
    PageSpec page,
    pw.Font bold,
  ) {
    if (text == null || text.isEmpty) return pw.SizedBox();

    final ink = style.ink;
    // A tenth of the ink strength, or a little more on the monochrome template
    // — it gets photocopied, and 10% grey does not always survive that.
    final alpha = style.isMonochrome
        ? DocumentWatermark.monochromeOpacity
        : DocumentWatermark.colourOpacity;

    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Align(
        // pdf's Alignment runs +1 at the *top*, the opposite of Flutter's.
        alignment: const pw.Alignment(
          0,
          1 - DocumentWatermark.verticalPosition * 2,
        ),
        child: pw.SizedBox(
          width: page.width * DocumentWatermark.widthFraction,
          child: pw.FittedBox(
            child: pw.Text(
              text,
              maxLines: 1,
              style: pw.TextStyle(
                font: bold,
                letterSpacing: 2,
                color: PdfColor(ink.r, ink.g, ink.b, alpha),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static pw.TextStyle _title(pw.Font bold, TemplateStyle style) => pw.TextStyle(
    font: bold,
    fontSize: style.titleSize,
    color: _pdf(style.ink),
  );

  static PdfColor _pdf(Color color) => PdfColor(
    color.r,
    color.g,
    color.b,
    color.a,
  );
}
