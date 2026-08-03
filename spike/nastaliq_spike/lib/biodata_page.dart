import 'package:flutter/material.dart';

import 'samples.dart';
import 'spec.dart';

/// The same layout as [PipelineA], built as a real Flutter widget tree so it
/// goes through HarfBuzz shaping. Laid out at exactly A4-at-72dpi logical
/// pixels, then captured at a high `pixelRatio` for print resolution.
class BiodataPage extends StatelessWidget {
  const BiodataPage({super.key, required this.doc});

  final SampleDoc doc;

  @override
  Widget build(BuildContext context) {
    final lh = LayoutSpec.lineHeight(doc.script);
    final family = LayoutSpec.flutterFamily(doc.script);
    final dir = doc.rtl ? TextDirection.rtl : TextDirection.ltr;

    final labelStyle = TextStyle(
      fontFamily: family,
      fontSize: LayoutSpec.labelSizePt,
      height: lh,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF374151),
      fontFamilyFallback: const ['NotoNaskhArabic'],
    );
    final valueStyle = TextStyle(
      fontFamily: family,
      fontSize: LayoutSpec.valueSizePt,
      height: lh,
      color: const Color(0xFF111827),
      fontFamilyFallback: const ['NotoNaskhArabic'],
    );

    Widget row(SampleRow r) {
      final label = SizedBox(
        width: LayoutSpec.labelColumnPt,
        child: Text(
          r.label,
          textDirection: dir,
          textAlign: doc.rtl ? TextAlign.right : TextAlign.left,
          style: labelStyle,
        ),
      );
      final value = Expanded(
        child: Text(
          r.value,
          textDirection: dir,
          textAlign: doc.rtl ? TextAlign.right : TextAlign.left,
          style: valueStyle,
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: LayoutSpec.rowGapPt),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          textDirection: TextDirection.ltr,
          children: doc.rtl
              ? [value, const SizedBox(width: 12), label]
              : [label, const SizedBox(width: 12), value],
        ),
      );
    }

    return Directionality(
      textDirection: dir,
      child: Container(
        width: LayoutSpec.pageWidthPt,
        height: LayoutSpec.pageHeightPt,
        color: Colors.white,
        padding: const EdgeInsets.all(LayoutSpec.marginPt),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                doc.heading,
                textDirection: dir,
                style: TextStyle(
                  fontFamily: family,
                  fontSize: LayoutSpec.headingSizePt,
                  height: lh,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                  fontFamilyFallback: const ['NotoNaskhArabic'],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(thickness: 0.8, color: Color(0xFF6B7280), height: 1),
            const SizedBox(height: 12),
            ...doc.rows.map(row),
            const SizedBox(height: 12),
            Text(
              doc.paragraph,
              textDirection: dir,
              textAlign: doc.rtl ? TextAlign.right : TextAlign.left,
              style: valueStyle,
            ),
            const SizedBox(height: 16),
            const Text(
              'ALPHABET COVERAGE',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              doc.alphabet,
              textDirection: dir,
              textAlign: doc.rtl ? TextAlign.right : TextAlign.left,
              style: valueStyle,
            ),
          ],
        ),
      ),
    );
  }
}
