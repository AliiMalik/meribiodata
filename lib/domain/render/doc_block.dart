import 'dart:ui' show Color;

/// The layout intermediate representation shared by both rendering backends.
///
/// A template turns a `RenderedDocument` into a list of these; the Flutter
/// renderer and the PDF renderer each interpret them. That is what makes
/// "one layout, two backends" (the M0 report's recommendation) real rather
/// than aspirational — a template is written once and cannot drift between the
/// raster and vector paths.
sealed class DocBlock {
  const DocBlock();

  /// Blocks that must not be separated by a page break from the block after
  /// them. A section heading alone at the foot of a page looks broken.
  bool get keepWithNext => false;
}

/// The document's main title, usually the candidate's name.
class DocTitle extends DocBlock {
  const DocTitle(this.text);

  final String text;

  @override
  bool get keepWithNext => true;
}

/// An optional line above the title — a Bismillah, a family name (§6.2).
class DocHeader extends DocBlock {
  const DocHeader(this.text);

  final String text;

  @override
  bool get keepWithNext => true;
}

class DocSectionTitle extends DocBlock {
  const DocSectionTitle(this.text);

  final String text;

  @override
  bool get keepWithNext => true;
}

/// One label/value pair — the substance of a biodata.
class DocRow extends DocBlock {
  const DocRow({
    required this.label,
    required this.value,
    this.isMasked = false,
  });

  final String label;
  final String value;

  /// Shareable mode changed this value (9.4). Templates may mark it.
  final bool isMasked;
}

class DocParagraph extends DocBlock {
  const DocParagraph(this.text);

  final String text;
}

class DocDivider extends DocBlock {
  const DocDivider({this.thickness = 0.8, this.color});

  final double thickness;
  final Color? color;

  @override
  bool get keepWithNext => true;
}

class DocSpacer extends DocBlock {
  const DocSpacer(this.height);

  final double height;
}

/// A footer line repeated on every page — the Phase 1 watermark.
class DocFooter extends DocBlock {
  const DocFooter(this.text);

  final String text;
}
