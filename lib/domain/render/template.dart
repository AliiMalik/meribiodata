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
