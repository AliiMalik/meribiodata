import 'samples.dart';

/// One layout spec shared by all three pipelines so the comparison is fair:
/// same page size, margins, sizes and line heights. Only the rendering
/// technology differs.
class LayoutSpec {
  static const pageWidthPt = 595.0; // A4 @ 72dpi
  static const pageHeightPt = 842.0;
  static const marginPt = 40.0;

  static const headingSizePt = 22.0;
  static const labelSizePt = 12.0;
  static const valueSizePt = 12.0;
  static const bodySizePt = 12.0;
  static const labelColumnPt = 150.0;
  static const rowGapPt = 10.0;

  /// Nastaliq stacks letters vertically and drops long descenders; 1.4 (the
  /// Latin default) collides. See section 4 of the build prompt.
  static double lineHeight(ScriptFamily s) => switch (s) {
    ScriptFamily.nastaliq => 2.1,
    ScriptFamily.naskh => 1.7,
    ScriptFamily.latin => 1.4,
  };

  static String flutterFamily(ScriptFamily s) => switch (s) {
    ScriptFamily.nastaliq => 'NotoNastaliqUrdu',
    ScriptFamily.naskh => 'NotoNaskhArabic',
    ScriptFamily.latin => 'Roboto',
  };

  static String fontAsset(ScriptFamily s, {bool bold = false}) => switch (s) {
    ScriptFamily.nastaliq =>
      'assets/fonts/NotoNastaliqUrdu-${bold ? 'Bold' : 'Regular'}.ttf',
    ScriptFamily.naskh =>
      'assets/fonts/NotoNaskhArabic-${bold ? 'Bold' : 'Regular'}.ttf',
    // Latin uses the PDF built-in / WebView default; no asset needed.
    ScriptFamily.latin =>
      'assets/fonts/NotoNaskhArabic-${bold ? 'Bold' : 'Regular'}.ttf',
  };
}

/// Result of one pipeline run, for the report table.
class PipelineResult {
  PipelineResult({
    required this.pipeline,
    required this.langCode,
    required this.millis,
    required this.bytes,
    required this.pageCount,
    this.error,
  });

  final String pipeline;
  final String langCode;
  final int millis;
  final int bytes;
  final int pageCount;
  final String? error;

  Map<String, Object?> toJson() => {
    'pipeline': pipeline,
    'lang': langCode,
    'ms': millis,
    'bytes': bytes,
    'pages': pageCount,
    'error': error,
  };
}
