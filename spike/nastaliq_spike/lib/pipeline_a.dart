import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'samples.dart';
import 'spec.dart';

/// Pipeline A — vector text in the PDF.
///
/// The `pdf` package does not run OpenType GSUB. When `textDirection` is RTL
/// and the string contains Arabic-range codepoints it calls its internal
/// `arabic.convert()`, which maps logical Unicode to Arabic Presentation Forms
/// (U+FB50-FDFF / U+FE70-FEFF) and reverses the run. That is exactly what the
/// standalone `arabic_reshaper` package does, so testing the built-in path
/// tests the whole Pipeline A family.
class PipelineA {
  static Future<Uint8List> build(SampleDoc doc) async {
    final base = pw.Font.ttf(await rootBundle.load(LayoutSpec.fontAsset(doc.script)));
    final bold = pw.Font.ttf(
      await rootBundle.load(LayoutSpec.fontAsset(doc.script, bold: true)),
    );
    // Naskh as fallback for anything Nastaliq lacks; Helvetica for Latin runs.
    final fallback = pw.Font.ttf(
      await rootBundle.load(LayoutSpec.fontAsset(ScriptFamily.naskh)),
    );

    final lh = LayoutSpec.lineHeight(doc.script);
    final dir = doc.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: base,
        bold: bold,
        fontFallback: [fallback, pw.Font.helvetica()],
      ),
    );

    pw.Widget row(SampleRow r) {
      final label = pw.SizedBox(
        width: LayoutSpec.labelColumnPt,
        child: pw.Text(
          r.label,
          textDirection: dir,
          textAlign: doc.rtl ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(
            font: bold,
            fontSize: LayoutSpec.labelSizePt,
            height: lh,
            color: PdfColors.grey800,
          ),
        ),
      );
      final value = pw.Expanded(
        child: pw.Text(
          r.value,
          textDirection: dir,
          textAlign: doc.rtl ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(fontSize: LayoutSpec.valueSizePt, height: lh),
        ),
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: LayoutSpec.rowGapPt),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: doc.rtl
              ? [value, pw.SizedBox(width: 12), label]
              : [label, pw.SizedBox(width: 12), value],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(LayoutSpec.marginPt),
        textDirection: dir,
        build: (context) => [
          pw.Center(
            child: pw.Text(
              doc.heading,
              textDirection: dir,
              style: pw.TextStyle(
                font: bold,
                fontSize: LayoutSpec.headingSizePt,
                height: lh,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(thickness: 0.8, color: PdfColors.grey600),
          pw.SizedBox(height: 12),
          ...doc.rows.map(row),
          pw.SizedBox(height: 12),
          pw.Text(
            doc.paragraph,
            textDirection: dir,
            textAlign: doc.rtl ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: LayoutSpec.bodySizePt, height: lh),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'ALPHABET COVERAGE',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            doc.alphabet,
            textDirection: dir,
            textAlign: doc.rtl ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(fontSize: LayoutSpec.bodySizePt, height: lh),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
