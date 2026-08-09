import 'dart:ui' show Color;

import 'package:meribiodata/domain/render/template.dart';

/// Templates that are a border image plus type chosen to sit inside it.
///
/// One class with fields rather than thirteen near-identical subclasses: they
/// differ only in artwork, colour and spacing, and a subclass per design would
/// be twelve copies of the same boilerplate waiting to drift apart.
class DecoratedTemplate extends DocumentTemplate {
  const DecoratedTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.backgroundAsset,
    required this.style,
    this.isLocked = false,
  });

  @override
  final String id;

  @override
  final String name;

  @override
  final TemplateCategory category;

  @override
  final String? backgroundAsset;

  @override
  final TemplateStyle style;

  @override
  final bool isLocked;
}

/// Ink used by the decorated set. Kept apart from the plain templates' palette
/// because these colours are chosen to answer a specific piece of artwork.
abstract final class _Ink {
  static const black = Color(0xFF111111);
  static const charcoal = Color(0xFF1F2937);
  static const grey = Color(0xFF4B5563);
  static const softGrey = Color(0xFF6B7280);
  static const rule = Color(0xFFD1D5DB);
  static const gold = Color(0xFF8A6D1F);
  static const navy = Color(0xFF1E3A5F);
  static const green = Color(0xFF14532D);
  static const olive = Color(0xFF5F6F3F);
  static const terracotta = Color(0xFF8A5A2B);
}

/// The shared shape of a decorated page.
///
/// [margin] is the number that matters and the one most easily got wrong: it
/// has to clear the artwork's frame, and every border sits at a different
/// inset. Too small and the first line of the biodata runs through the
/// ornament; too large and the page looks empty. Each template below sets its
/// own, measured against its own artwork.
TemplateStyle _style({
  required double margin,
  required Color accent,
  Color ink = _Ink.charcoal,
  Color muted = _Ink.grey,
  double labelWidth = 150,
  double titleSize = 23,
  double rowGap = 10,
  double sectionGap = 19,
  bool uppercase = true,
  bool sectionRule = true,
}) => TemplateStyle(
  margin: margin,
  titleSize: titleSize,
  sectionTitleSize: 13,
  labelSize: 11,
  valueSize: 12,
  labelColumnWidth: labelWidth,
  rowGap: rowGap,
  sectionGap: sectionGap,
  ink: ink,
  mutedInk: muted,
  rule: _Ink.rule,
  accent: accent,
  sectionTitleUppercase: uppercase,
  showSectionRule: sectionRule,
);

/// The border-art templates, grouped as the picker shows them.
///
/// The locked one in each category is the strongest design of that group.
/// Locking is per template and is data — moving one is a one-word edit here.
abstract final class DecoratedTemplates {
  // --- Classic ------------------------------------------------------------

  /// Gold filigree, the most ornate thing in the set.
  static final filigree = DecoratedTemplate(
    id: 'filigree',
    name: 'Filigree',
    category: TemplateCategory.classic,
    backgroundAsset: 'assets/templates/filigree.jpg',
    isLocked: true,
    // Roomier type: the artwork is busy, so the content needs air to not
    // compete with it.
    style: _style(margin: 84, accent: _Ink.gold, titleSize: 25, rowGap: 11),
  );

  static final flourish = DecoratedTemplate(
    id: 'flourish',
    name: 'Flourish',
    category: TemplateCategory.classic,
    backgroundAsset: 'assets/templates/flourish.jpg',
    style: _style(margin: 82, accent: _Ink.black, ink: _Ink.black),
  );

  static final boldFrame = DecoratedTemplate(
    id: 'bold-frame',
    name: 'Bold Frame',
    category: TemplateCategory.classic,
    backgroundAsset: 'assets/templates/bold-frame.jpg',
    // The heaviest border in the set, so the largest margin.
    style: _style(margin: 92, accent: _Ink.black, ink: _Ink.black),
  );

  // --- Geometric ----------------------------------------------------------

  static final deco = DecoratedTemplate(
    id: 'deco',
    name: 'Deco',
    category: TemplateCategory.geometric,
    backgroundAsset: 'assets/templates/deco.jpg',
    isLocked: true,
    style: _style(margin: 86, accent: _Ink.charcoal, ink: _Ink.black),
  );

  static final decoLight = DecoratedTemplate(
    id: 'deco-light',
    name: 'Deco Light',
    category: TemplateCategory.geometric,
    backgroundAsset: 'assets/templates/deco-light.jpg',
    style: _style(margin: 84, accent: _Ink.charcoal),
  );

  static final navyKey = DecoratedTemplate(
    id: 'navy-key',
    name: 'Navy Key',
    category: TemplateCategory.geometric,
    backgroundAsset: 'assets/templates/navy-key.jpg',
    style: _style(margin: 80, accent: _Ink.navy),
  );

  // --- Botanical (shown under Thematic) -----------------------------------

  static final greenFlower = DecoratedTemplate(
    id: 'green-flower',
    name: 'Green Flower',
    category: TemplateCategory.thematic,
    backgroundAsset: 'assets/templates/green-flower.jpg',
    isLocked: true,
    style: _style(margin: 76, accent: _Ink.green),
  );

  static final leafSprig = DecoratedTemplate(
    id: 'leaf-sprig',
    name: 'Leaf Sprig',
    category: TemplateCategory.thematic,
    backgroundAsset: 'assets/templates/leaf-sprig.jpg',
    // The widest margin in the set, and not for elegance: this artwork hangs a
    // sprig *inside* the page rather than framing its edge, and at a normal
    // margin the leaves ran straight through the label column. The label
    // column narrows to buy that back, so values still have room to breathe.
    style: _style(
      margin: 132,
      labelWidth: 118,
      accent: _Ink.olive,
      uppercase: false,
      sectionRule: false,
    ),
  );

  static final olive = DecoratedTemplate(
    id: 'olive',
    name: 'Olive',
    category: TemplateCategory.thematic,
    backgroundAsset: 'assets/templates/olive.jpg',
    // Same shape of problem as Leaf Sprig but milder: the sprig sits in the
    // top-left corner rather than descending the page.
    style: _style(
      margin: 100,
      labelWidth: 132,
      accent: _Ink.olive,
      uppercase: false,
    ),
  );

  // --- Minimal (shown under Creative) -------------------------------------

  static final navyWedge = DecoratedTemplate(
    id: 'navy-wedge',
    name: 'Navy Wedge',
    category: TemplateCategory.creative,
    backgroundAsset: 'assets/templates/navy-wedge.jpg',
    isLocked: true,
    style: _style(margin: 74, accent: _Ink.navy),
  );

  static final thinRule = DecoratedTemplate(
    id: 'thin-rule',
    name: 'Thin Rule',
    category: TemplateCategory.creative,
    backgroundAsset: 'assets/templates/thin-rule.jpg',
    style: _style(margin: 76, accent: _Ink.charcoal, muted: _Ink.softGrey),
  );

  static final peach = DecoratedTemplate(
    id: 'peach',
    name: 'Peach',
    category: TemplateCategory.creative,
    backgroundAsset: 'assets/templates/peach.jpg',
    style: _style(margin: 74, accent: _Ink.terracotta, uppercase: false),
  );

  static final paper = DecoratedTemplate(
    id: 'paper',
    name: 'Paper',
    category: TemplateCategory.creative,
    backgroundAsset: 'assets/templates/paper.jpg',
    style: _style(margin: 76, accent: _Ink.charcoal, muted: _Ink.softGrey),
  );

  static final all = <DocumentTemplate>[
    filigree,
    flourish,
    boldFrame,
    deco,
    decoLight,
    navyKey,
    greenFlower,
    leafSprig,
    olive,
    navyWedge,
    thinRule,
    peach,
    paper,
  ];
}
