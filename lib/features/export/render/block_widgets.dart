import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:meribiodata/domain/render/doc_block.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

/// Draws the layout IR as Flutter widgets.
///
/// This is the raster backend (Pipeline B, D1) — the one that renders
/// Perso-Arabic correctly, because Flutter shapes text with HarfBuzz.
class BlockWidgets {
  const BlockWidgets({
    required this.style,
    required this.language,
    this.contentWidth = 0,
    this.images = const {},
  });

  final TemplateStyle style;
  final LanguageDescriptor language;

  /// Page width less margins. A photo sizes itself as a fraction of this, so a
  /// template needs no knowledge of the page it will land on.
  final double contentWidth;

  /// Photos already decoded, keyed by the JPEG bytes they came from.
  ///
  /// [Image.memory] decodes asynchronously and paints a frame late. That is
  /// invisible on screen and fatal off it: the export captures a fixed number
  /// of frames, so a late decode means a blank rectangle where the face should
  /// be. The exporter decodes up front and passes the results here, and
  /// [RawImage] paints them synchronously.
  ///
  /// Keyed by the bytes rather than by the [DocPhoto]: a template builds a
  /// fresh block list on every call, so a block identity would only match if
  /// the caller happened to reuse the exact list it decoded from. The bytes
  /// come straight off the document and are the same object either way.
  final Map<Uint8List, ui.Image> images;

  TextStyle _base(double size, {Color? color, FontWeight? weight}) => TextStyle(
    fontFamily: language.documentFontFamily,
    fontFamilyFallback: language.documentFontFallback,
    fontSize: size,
    height: language.lineHeight,
    color: color ?? style.ink,
    fontWeight: weight,
  );

  TextAlign get _align => language.isRtl ? TextAlign.right : TextAlign.left;

  Widget build(DocBlock block) => switch (block) {
    DocHeader(:final text) => Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: _base(
          style.valueSize + 1,
          color: style.accent ?? style.mutedInk,
        ),
      ),
    ),
    DocTitle(:final text) => Align(
      alignment: style.titleCentred
          ? Alignment.center
          : AlignmentDirectional.centerStart,
      child: Text(
        text,
        textAlign: style.titleCentred ? TextAlign.center : _align,
        style: _base(style.titleSize, weight: FontWeight.w700),
      ),
    ),
    DocSectionTitle(:final text) => Text(
      text,
      textAlign: _align,
      style: _base(
        style.sectionTitleSize,
        color: style.accent ?? style.ink,
        weight: FontWeight.w700,
      ),
    ),
    DocRow(:final label, :final value) => Padding(
      padding: EdgeInsets.only(bottom: style.rowGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        // The row is laid out in document order explicitly rather than via
        // Directionality, so the label column stays on the reading-start side
        // in both directions without a second code path.
        textDirection: TextDirection.ltr,
        children: language.isRtl
            ? [
                Expanded(child: _value(value)),
                SizedBox(width: style.rowGap),
                SizedBox(width: style.labelColumnWidth, child: _label(label)),
              ]
            : [
                SizedBox(width: style.labelColumnWidth, child: _label(label)),
                SizedBox(width: style.rowGap),
                Expanded(child: _value(value)),
              ],
      ),
    ),
    DocParagraph(:final text) => Text(
      text,
      textAlign: _align,
      style: _base(style.valueSize),
    ),
    DocDivider(:final thickness, :final color) => Container(
      height: thickness,
      color: color ?? style.rule,
    ),
    DocSpacer(:final height) => SizedBox(height: height),
    final DocPhoto photo => _photo(photo),
    // Zero height by design: the paginator acts on the block's presence, not
    // on its size.
    DocPageBreak() => const SizedBox.shrink(),
  };

  Widget _photo(DocPhoto block) {
    final width = contentWidth * block.widthFraction;
    final decoded = images[block.bytes];

    return Center(
      child: SizedBox(
        width: width,
        height: width / block.aspectRatio,
        child: decoded == null
            ? Image.memory(block.bytes, fit: BoxFit.cover)
            : RawImage(image: decoded, fit: BoxFit.cover),
      ),
    );
  }

  Widget _label(String label) => Text(
    label,
    textAlign: _align,
    style: _base(
      style.labelSize,
      color: style.mutedInk,
      weight: FontWeight.w700,
    ),
  );

  Widget _value(String value) =>
      Text(value, textAlign: _align, style: _base(style.valueSize));
}

/// The full document as one tall column, at page width.
///
/// Laid out once; the paginator measures it and then renders slices of it, so
/// there is exactly one layout pass and page N always looks like the same
/// content did when measured.
class DocumentColumn extends StatelessWidget {
  const DocumentColumn({
    required this.blocks,
    required this.style,
    required this.language,
    required this.width,
    this.blockKeys,
    this.images = const {},
    super.key,
  });

  final List<DocBlock> blocks;
  final TemplateStyle style;
  final LanguageDescriptor language;
  final double width;

  /// One key per block, used by the paginator to read heights.
  final List<GlobalKey>? blockKeys;

  final Map<Uint8List, ui.Image> images;

  @override
  Widget build(BuildContext context) {
    final painter = BlockWidgets(
      style: style,
      language: language,
      contentWidth: width,
      images: images,
    );

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++)
            KeyedSubtree(
              key: blockKeys == null ? null : blockKeys![i],
              child: painter.build(blocks[i]),
            ),
        ],
      ),
    );
  }
}

/// One page: white paper, margins, and the slice of the column that belongs
/// on this page.
class DocumentPage extends StatelessWidget {
  const DocumentPage({
    required this.blocks,
    required this.style,
    required this.language,
    required this.page,
    required this.offsetY,
    required this.height,
    this.watermark,
    this.images = const {},
    super.key,
  });

  final List<DocBlock> blocks;
  final TemplateStyle style;
  final LanguageDescriptor language;
  final PageSpec page;

  /// How far into the tall column this page starts.
  final double offsetY;

  /// Visible height of the content area on this page.
  final double height;

  /// Painted behind the content, on every page. Null suppresses it.
  final String? watermark;

  final Map<Uint8List, ui.Image> images;

  @override
  Widget build(BuildContext context) {
    final contentWidth = page.width - style.margin * 2;

    return Container(
      width: page.width,
      height: page.height,
      color: Colors.white,
      child: Stack(
        children: [
          if (watermark case final String mark when mark.isNotEmpty)
            Positioned.fill(
              child: DocumentWatermark(
                text: mark,
                style: style,
                page: page,
              ),
            ),
          Padding(
            padding: EdgeInsets.all(style.margin),
            child: _content(contentWidth),
          ),
        ],
      ),
    );
  }

  Widget _content(double contentWidth) {
    return ClipRect(
      child: SizedBox(
        width: contentWidth,
        height: height,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Transform.translate(
            offset: Offset(0, -offsetY),
            child: DocumentColumn(
              blocks: blocks,
              style: style,
              language: language,
              width: contentWidth,
              images: images,
            ),
          ),
        ),
      ),
    );
  }
}

/// The "made with" mark, laid across the lower part of the page.
///
/// Deliberately not a footer line any more. A small line of grey type at the
/// bottom of a page is trivially cropped off, and cropping is exactly what
/// someone passing the work off as their own would do. A wide, translucent band
/// sitting *behind* the text cannot be removed without removing the biodata
/// with it — and because it is only about a tenth of the ink strength, it does
/// not compete with anything printed in front of it.
///
/// It is a page background rather than a block in the flow, so it repeats on
/// every page and costs the paginator nothing.
class DocumentWatermark extends StatelessWidget {
  const DocumentWatermark({
    required this.text,
    required this.style,
    required this.page,
    super.key,
  });

  final String text;
  final TemplateStyle style;
  final PageSpec page;

  /// Share of the page width the mark spans.
  static const widthFraction = 0.86;

  /// Where its centre sits, as a share of page height. Low enough to read as a
  /// mark on the paper rather than as a heading, high enough to still be behind
  /// body text on a full page.
  static const verticalPosition = 0.72;

  static const colourOpacity = 0.10;

  /// A monochrome template gets a slightly stronger mark: it is printed and
  /// photocopied at a corner shop, and 10% grey does not always survive that.
  static const monochromeOpacity = 0.13;

  double get opacity => style.isMonochrome ? monochromeOpacity : colourOpacity;

  @override
  Widget build(BuildContext context) {
    final width = page.width * widthFraction;

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, verticalPosition * 2 - 1),
        child: SizedBox(
          width: width,
          child: FittedBox(
            child: Text(
              text,
              maxLines: 1,
              style: TextStyle(
                // Inter regardless of document language: the mark is the app's
                // name, not part of the biodata, and it must set identically
                // whatever script the document is in.
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
                color: style.ink.withValues(alpha: opacity),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
