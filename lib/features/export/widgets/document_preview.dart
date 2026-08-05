import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/features/export/render/block_widgets.dart';

/// Shows page one of a document, scaled to fit.
///
/// Renders through exactly the same widgets the export uses, so the preview is
/// the document rather than an approximation of it — which is what makes the
/// M5 promise that "preview must render the actual selected mode" (9.4)
/// possible to keep.
class DocumentPreview extends StatelessWidget {
  const DocumentPreview({
    required this.document,
    required this.template,
    required this.page,
    this.maxWidth = 320,
    super.key,
  });

  final RenderedDocument document;
  final DocumentTemplate template;
  final PageSpec page;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scale = maxWidth / page.width;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: page.width * scale,
        height: page.height * scale,
        // FittedBox, not a SizedBox — a SizedBox would clamp the page to the
        // available width and quietly render a squashed layout. Same trap the
        // M0 capture harness fell into.
        child: FittedBox(
          child: DocumentPage(
            blocks: template.blocks(document),
            style: template.style,
            language: document.language,
            page: page,
            offsetY: 0,
            height: page.height - template.style.margin * 2,
            watermark: document.watermark,
          ),
        ),
      ),
    );
  }
}
