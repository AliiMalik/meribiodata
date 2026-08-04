import 'dart:ui' show Color;

import 'package:meribiodata/domain/render/doc_block.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/render/template.dart';

/// Document ink. Deliberately separate from `AppColors`: a biodata should look
/// like formal printed stationery, not like the app (§10).
abstract final class _Ink {
  static const black = Color(0xFF111111);
  static const charcoal = Color(0xFF1F2937);
  static const grey = Color(0xFF4B5563);
  static const lightRule = Color(0xFFD1D5DB);

  /// Full-strength rule for the print-shop template, which cannot rely on a
  /// light grey surviving a photocopier.
  static const hairline = Color(0xFF000000);

  /// Restrained green, darker than the app's brand green so it stays legible
  /// in print and does not shout.
  static const formalGreen = Color(0xFF14532D);

  /// Emphasis only, used sparingly (§10).
  static const gold = Color(0xFF8A6D1F);
}

/// The default. Clean, generous, quietly formal.
class ClassicTemplate extends DocumentTemplate {
  const ClassicTemplate();

  @override
  String get id => 'classic';

  @override
  String get name => 'Classic';

  @override
  TemplateStyle get style => const TemplateStyle(
    margin: 48,
    titleSize: 22,
    sectionTitleSize: 13,
    labelSize: 11,
    valueSize: 12,
    labelColumnWidth: 150,
    rowGap: 10,
    sectionGap: 18,
    ink: _Ink.charcoal,
    mutedInk: _Ink.grey,
    rule: _Ink.lightRule,
    accent: _Ink.formalGreen,
    sectionTitleUppercase: true,
  );
}

/// Black and white only, heavier rules, tighter margins.
///
/// Exists because many users will print at a corner shop in black and white
/// (§10) — a template that relies on colour turns into grey mush there.
class PrintShopTemplate extends DocumentTemplate {
  const PrintShopTemplate();

  @override
  String get id => 'printshop';

  @override
  String get name => 'Print Shop (black & white)';

  @override
  TemplateStyle get style => const TemplateStyle(
    margin: 40,
    titleSize: 20,
    sectionTitleSize: 12,
    labelSize: 11,
    valueSize: 12,
    labelColumnWidth: 145,
    rowGap: 9,
    sectionGap: 16,
    ink: _Ink.black,
    mutedInk: _Ink.black,
    rule: _Ink.hairline,
    sectionTitleUppercase: true,
  );
}

/// Roomier type and leading for a shorter biodata, or for older readers.
class ElegantTemplate extends DocumentTemplate {
  const ElegantTemplate();

  @override
  String get id => 'elegant';

  @override
  String get name => 'Elegant';

  @override
  TemplateStyle get style => const TemplateStyle(
    margin: 56,
    titleSize: 26,
    sectionTitleSize: 14,
    labelSize: 12,
    valueSize: 13,
    labelColumnWidth: 160,
    rowGap: 13,
    sectionGap: 24,
    ink: _Ink.charcoal,
    mutedInk: _Ink.grey,
    rule: _Ink.lightRule,
    accent: _Ink.gold,
  );
}

/// Fits more on a page: narrower label column, tighter gaps, no section rules.
///
/// For the 60-field case from §6.3, where the point is to paginate gracefully
/// rather than to look airy.
class CompactTemplate extends DocumentTemplate {
  const CompactTemplate();

  @override
  String get id => 'compact';

  @override
  String get name => 'Compact';

  @override
  TemplateStyle get style => const TemplateStyle(
    margin: 36,
    titleSize: 18,
    sectionTitleSize: 11,
    labelSize: 10,
    valueSize: 11,
    labelColumnWidth: 130,
    rowGap: 6,
    sectionGap: 12,
    ink: _Ink.charcoal,
    mutedInk: _Ink.grey,
    rule: _Ink.lightRule,
    accent: _Ink.formalGreen,
    sectionTitleUppercase: true,
    titleCentred: false,
    showSectionRule: false,
  );

  /// Compact puts the section title and its first rule on one line to save
  /// vertical space, so it overrides the default block stream.
  @override
  List<DocBlock> blocks(RenderedDocument document) {
    final blocks = <DocBlock>[];

    if (document.headerText case final String header when header.isNotEmpty) {
      blocks.add(DocHeader(header));
    }
    blocks
      ..add(DocTitle(document.title))
      ..add(DocSpacer(style.rowGap));

    for (final section in document.nonEmptySections) {
      blocks
        ..add(DocSectionTitle(section.title.toUpperCase()))
        ..add(const DocDivider(thickness: 0.5, color: _Ink.lightRule))
        ..add(DocSpacer(style.rowGap / 2));

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

    if (document.watermark case final String mark when mark.isNotEmpty) {
      blocks.add(DocFooter(mark));
    }

    return blocks;
  }
}

/// The shipped templates, in picker order.
abstract final class Templates {
  static const classic = ClassicTemplate();
  static const printShop = PrintShopTemplate();
  static const elegant = ElegantTemplate();
  static const compact = CompactTemplate();

  static const all = <DocumentTemplate>[classic, printShop, elegant, compact];

  static const defaultId = 'classic';

  static DocumentTemplate byId(String? id) =>
      all.firstWhere((t) => t.id == id, orElse: () => classic);
}
