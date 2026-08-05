import 'dart:typed_data';
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

/// The candidate's photo (9.3).
///
/// Carries the JPEG bytes rather than a path, for the same reason every other
/// block carries finished text: a template must be renderable from a value, so
/// that a golden test can pin one without touching the filesystem.
///
/// [widthFraction] is of the page's content width — the renderers know that,
/// templates do not, and a fixed point size would swamp the 4x6 card page.
class DocPhoto extends DocBlock {
  const DocPhoto({
    required this.bytes,
    required this.widthFraction,
    this.aspectRatio = 3 / 4,
  });

  final Uint8List bytes;
  final double widthFraction;

  /// Width over height. Portrait, so below 1.
  final double aspectRatio;
}

/// Forces everything after it onto a new page (9.3, the separate photo page).
///
/// Zero height, so it costs nothing when the renderer measures the column.
class DocPageBreak extends DocBlock {
  const DocPageBreak();
}
