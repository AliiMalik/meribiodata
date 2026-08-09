import 'dart:ui' show Color;

import 'package:meribiodata/domain/render/doc_block.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';

/// Page geometry, in PDF points (1/72 inch).
class PageSpec {
  const PageSpec({
    required this.id,
    required this.width,
    required this.height,
  });

  /// The only page size (D18).
  ///
  /// US Letter and a 4x6 card were offered until M6 and removed: nobody in the
  /// target market asks for them, and every decorated template would have had
  /// to be drawn or safely croppable at three different aspect ratios. One
  /// shape means template artwork is one file that fits exactly.
  static const a4 = PageSpec(id: 'a4', width: 595, height: 842);

  final String id;
  final double width;
  final double height;
}

/// Everything a renderer needs to draw a template's blocks.
///
/// Documents are their own design surface, deliberately unlike the app UI:
/// restrained ink, generous margins (§10). None of the app's greens belong
/// here by default.
class TemplateStyle {
  const TemplateStyle({
    required this.margin,
    required this.titleSize,
    required this.sectionTitleSize,
    required this.labelSize,
    required this.valueSize,
    required this.labelColumnWidth,
    required this.rowGap,
    required this.sectionGap,
    required this.ink,
    required this.mutedInk,
    required this.rule,
    this.accent,
    this.sectionTitleUppercase = false,
    this.titleCentred = true,
    this.showSectionRule = true,
  });

  final double margin;
  final double titleSize;
  final double sectionTitleSize;
  final double labelSize;
  final double valueSize;
  final double labelColumnWidth;
  final double rowGap;
  final double sectionGap;

  final Color ink;
  final Color mutedInk;
  final Color rule;

  /// Null for the monochrome print-shop template.
  final Color? accent;

  final bool sectionTitleUppercase;
  final bool titleCentred;
  final bool showSectionRule;

  bool get isMonochrome => accent == null;

  /// The same style with every text size moved by [delta] points.
  ///
  /// Gaps and margins are deliberately untouched. That is what keeps a larger
  /// setting safely inside the template's border artwork — the frame clearance
  /// is a function of the margin, and the margin does not move. Bigger text
  /// simply uses more of the column and may run to another page, which is the
  /// honest consequence and not a layout failure.
  TemplateStyle withTextDelta(double delta) {
    if (delta == 0) return this;
    return TemplateStyle(
      margin: margin,
      titleSize: titleSize + delta,
      sectionTitleSize: sectionTitleSize + delta,
      labelSize: labelSize + delta,
      valueSize: valueSize + delta,
      labelColumnWidth: labelColumnWidth,
      rowGap: rowGap,
      sectionGap: sectionGap,
      ink: ink,
      mutedInk: mutedInk,
      rule: rule,
      accent: accent,
      sectionTitleUppercase: sectionTitleUppercase,
      titleCentred: titleCentred,
      showSectionRule: showSectionRule,
    );
  }
}

/// How large the document's text is (#34).
///
/// Three steps of one point each, and no more. The constraint is the artwork:
/// every decorated template's margin is measured against its own border, so
/// text that grew appreciably would either overrun the frame or force the
/// margins to move and spoil the design. One point is enough to matter to a
/// reader who needs it, and small enough that no template has to be redrawn.
enum DocumentTextSize {
  normal(0),
  large(1),
  largest(2);

  const DocumentTextSize(this.delta);

  /// Points added to every text size in the template.
  final double delta;

  static DocumentTextSize byName(String? name) => values.firstWhere(
    (size) => size.name == name,
    orElse: () => normal,
  );
}

/// Picker headings, in display order.
///
/// Purely presentational grouping. Nothing about a category implies whether its
/// templates are locked — that is per-template, so a category can hold both.
enum TemplateCategory {
  standard,
  classic,
  creative,
  thematic,
  geometric,
  religious,
}

/// A template is layout, typography and ornament — never a fixed field list.
///
/// It renders whatever schema exists (§6.4), so it must survive zero optional
/// fields, every field, a hidden section, a custom section, and a 60-character
/// custom label.
abstract class DocumentTemplate {
  const DocumentTemplate();

  /// Stable id, stored on the profile. Never change one that has shipped.
  String get id;

  /// Shown in the picker. Not translated in M3 — template names are brand-ish
  /// and the picker shows a live thumbnail anyway.
  String get name;

  /// Which heading the picker files this under.
  TemplateCategory get category => TemplateCategory.standard;

  /// Full-page border artwork drawn behind the content, or null for a plain
  /// page.
  ///
  /// An asset path rather than bytes, so a template stays a `const` value and
  /// each renderer decodes it at the size it actually needs — a decoded A4
  /// background is about 15 MB, and the picker shows thirteen of them at once
  /// (NFR-2 targets 3 GB phones).
  String? get backgroundAsset => null;

  /// True when the page is not plain white, which the watermark needs to know:
  /// a translucent band that reads well on white can vanish on a tinted page.
  bool get hasBackground => backgroundAsset != null;

  /// Whether this one carries a lock in the picker (D19).
  ///
  /// A locked template is still rendered in the picker at full fidelity — the
  /// user sees their own biodata in it before deciding. Hiding the design
  /// behind a blur would remove the only reason anyone would watch an ad for
  /// it.
  bool get isLocked => false;

  /// True when the template prints without colour, for corner-shop printing.
  bool get isMonochrome => style.isMonochrome;

  TemplateStyle get style;

  /// Photo width as a fraction of the content width (9.3).
  ///
  /// Modest inline, because the photo sits above the details and should not
  /// push them onto a second page; generous when it has a page to itself,
  /// which is the whole reason for asking for one.
  static const inlinePhotoFraction = 0.34;
  static const fullPagePhotoFraction = 0.62;

  /// The photo where it sits in the flow, under the name. Empty when there is
  /// no photo or the user asked for it on its own page.
  List<DocBlock> inlinePhoto(RenderedDocument document) {
    final photo = document.photo;
    if (photo == null || document.photoOnSeparatePage) return const [];
    return [
      DocPhoto(bytes: photo, widthFraction: inlinePhotoFraction),
      DocSpacer(style.sectionGap),
    ];
  }

  /// The photo on a page of its own, at the end of the document.
  ///
  /// At the end rather than the front: when the biodata is shared as images,
  /// the photo is then the last file, and a sender who wants to pass on the
  /// details without the picture simply does not forward it.
  List<DocBlock> photoPage(RenderedDocument document) {
    final photo = document.photo;
    if (photo == null || !document.photoOnSeparatePage) return const [];
    return [
      const DocPageBreak(),
      DocSpacer(style.sectionGap),
      DocPhoto(bytes: photo, widthFraction: fullPagePhotoFraction),
    ];
  }

  /// This template with its text at [size].
  ///
  /// Returns `this` at the normal size, so the common case allocates nothing
  /// and every existing golden keeps comparing against the identical object.
  DocumentTemplate resized(DocumentTextSize size) =>
      size == DocumentTextSize.normal ? this : _ResizedTemplate(this, size);

  /// Turns a document into the block stream both renderers consume.
  List<DocBlock> blocks(RenderedDocument document) {
    final blocks = <DocBlock>[];

    if (document.headerText case final String header when header.isNotEmpty) {
      blocks
        ..add(DocHeader(header))
        ..add(DocSpacer(style.rowGap));
    }

    blocks.add(DocTitle(document.title));
    if (style.showSectionRule) {
      blocks
        ..add(DocSpacer(style.rowGap))
        ..add(DocDivider(color: style.rule));
    }
    blocks
      ..add(DocSpacer(style.sectionGap))
      ..addAll(inlinePhoto(document));

    for (final section in document.nonEmptySections) {
      blocks
        ..add(
          DocSectionTitle(
            style.sectionTitleUppercase
                ? section.title.toUpperCase()
                : section.title,
          ),
        )
        ..add(DocSpacer(style.rowGap));

      for (final field in section.fields) {
        blocks.add(
          DocRow(
            label: field.label,
            value: field.value,
            isMasked: field.wasMasked,
          ),
        );
      }
      blocks.add(DocSpacer(style.sectionGap));
    }

    blocks.addAll(photoPage(document));
    return blocks;
  }
}

/// A template wearing a different text size.
///
/// Delegates `blocks` to the original rather than reimplementing it, which is
/// safe precisely because [TemplateStyle.withTextDelta] leaves gaps alone: the
/// block stream embeds spacer heights, so identical gaps mean an identical
/// stream. Had the delta touched `rowGap`, this delegation would silently
/// desync the spacing from the type.
class _ResizedTemplate extends DocumentTemplate {
  const _ResizedTemplate(this._base, this._size);

  final DocumentTemplate _base;
  final DocumentTextSize _size;

  @override
  String get id => _base.id;

  @override
  String get name => _base.name;

  @override
  TemplateCategory get category => _base.category;

  @override
  bool get isLocked => _base.isLocked;

  @override
  String? get backgroundAsset => _base.backgroundAsset;

  @override
  TemplateStyle get style => _base.style.withTextDelta(_size.delta);

  @override
  List<DocBlock> blocks(RenderedDocument document) => _base.blocks(document);
}
