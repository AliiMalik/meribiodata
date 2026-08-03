import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'samples.dart';
import 'spec.dart';

/// Pipeline C — hand the layout to the Android WebView as HTML and let it
/// print to PDF. The WebView runs full OpenType shaping and emits vector text.
///
/// Two known risks, both checked by this spike:
///  1. `Printing.convertHtml` is marked @Deprecated as of printing 5.15.0.
///  2. WebView is Play-updated, so output can differ between an API 26 device
///     and a current one.
class PipelineC {
  static Future<Uint8List> build(SampleDoc doc) async {
    final fontB64 = base64Encode(
      (await rootBundle.load(LayoutSpec.fontAsset(doc.script)))
          .buffer
          .asUint8List(),
    );
    final boldB64 = base64Encode(
      (await rootBundle.load(LayoutSpec.fontAsset(doc.script, bold: true)))
          .buffer
          .asUint8List(),
    );

    final lh = LayoutSpec.lineHeight(doc.script);
    final dir = doc.rtl ? 'rtl' : 'ltr';
    final align = doc.rtl ? 'right' : 'left';

    final rows = doc.rows
        .map(
          (r) =>
              '<tr><th>${_esc(r.label)}</th><td>${_esc(r.value)}</td></tr>',
        )
        .join();

    final html =
        '''
<!DOCTYPE html>
<html dir="$dir">
<head>
<meta charset="utf-8">
<style>
  @font-face {
    font-family: 'DocFont';
    font-weight: 400;
    src: url(data:font/truetype;charset=utf-8;base64,$fontB64) format('truetype');
  }
  @font-face {
    font-family: 'DocFont';
    font-weight: 700;
    src: url(data:font/truetype;charset=utf-8;base64,$boldB64) format('truetype');
  }
  @page { size: A4; margin: ${LayoutSpec.marginPt}pt; }
  body {
    font-family: 'DocFont', serif;
    direction: $dir;
    text-align: $align;
    line-height: $lh;
    margin: 0;
    color: #111827;
  }
  h1 {
    font-size: ${LayoutSpec.headingSizePt}pt;
    font-weight: 700;
    text-align: center;
    margin: 0 0 8pt 0;
  }
  hr { border: none; border-top: 0.8pt solid #6b7280; margin: 0 0 12pt 0; }
  table { width: 100%; border-collapse: collapse; }
  th {
    width: ${LayoutSpec.labelColumnPt}pt;
    font-size: ${LayoutSpec.labelSizePt}pt;
    font-weight: 700;
    color: #374151;
    text-align: $align;
    vertical-align: top;
    padding: 0 0 ${LayoutSpec.rowGapPt}pt 0;
  }
  td {
    font-size: ${LayoutSpec.valueSizePt}pt;
    text-align: $align;
    vertical-align: top;
    padding: 0 12pt ${LayoutSpec.rowGapPt}pt 12pt;
  }
  p { font-size: ${LayoutSpec.bodySizePt}pt; margin: 12pt 0 0 0; }
  .cap {
    font-family: sans-serif; font-size: 9pt; font-weight: 700;
    color: #6b7280; direction: ltr; text-align: left;
    margin: 16pt 0 4pt 0;
  }
</style>
</head>
<body>
  <h1>${_esc(doc.heading)}</h1>
  <hr>
  <table>$rows</table>
  <p>${_esc(doc.paragraph)}</p>
  <div class="cap">ALPHABET COVERAGE</div>
  <p style="margin-top:0">${_esc(doc.alphabet)}</p>
</body>
</html>
''';

    // ignore: deprecated_member_use
    return Printing.convertHtml(html: html, format: PdfPageFormat.a4);
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
