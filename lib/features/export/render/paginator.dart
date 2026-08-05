import 'package:meribiodata/domain/render/doc_block.dart';
import 'package:meribiodata/domain/render/template.dart';

/// Where one page starts and how much of the column it shows.
class PageSlice {
  const PageSlice({required this.offsetY, required this.height});

  final double offsetY;
  final double height;
}

/// Splits a measured column into pages.
///
/// Pipeline B rasterizes a fixed-size page, so it cannot lean on
/// `pw.MultiPage` the way the vector backend does — pagination is ours to do.
/// This is the piece the M0 report flagged as real work, and it is where the
/// 60-field case from §6.3 either paginates or clips.
abstract final class Paginator {
  /// [heights] is one measured height per block, in the same order.
  ///
  /// Never splits a block across pages unless the block is taller than a whole
  /// page, in which case it splits rather than looping forever. A block marked
  /// [DocBlock.keepWithNext] is pulled to the next page along with its
  /// follower, so a section heading never ends up stranded at the foot.
  static List<PageSlice> paginate({
    required List<DocBlock> blocks,
    required List<double> heights,
    required double pageHeight,
  }) {
    assert(
      blocks.length == heights.length,
      'every block needs a measured height',
    );
    if (blocks.isEmpty || pageHeight <= 0) {
      return const [PageSlice(offsetY: 0, height: 0)];
    }

    final offsets = <double>[];
    var running = 0.0;
    for (final height in heights) {
      offsets.add(running);
      running += height;
    }
    final totalHeight = running;

    final slices = <PageSlice>[];
    var pageStart = 0.0;
    var index = 0;

    while (index < blocks.length) {
      // A break that lands at the top of a page has already done its job.
      // Emitting a slice for it would produce a blank page.
      if (blocks[index] is DocPageBreak) {
        index++;
        continue;
      }

      final pageEnd = pageStart + pageHeight;
      var lastFitting = -1;

      for (var i = index; i < blocks.length; i++) {
        if (offsets[i] + heights[i] <= pageEnd) {
          lastFitting = i;
        } else {
          break;
        }
      }

      if (lastFitting < index) {
        // The very first block does not fit a whole page. Split inside it;
        // clipping it away would silently lose content.
        slices.add(PageSlice(offsetY: pageStart, height: pageHeight));
        pageStart = pageEnd;
        while (index < blocks.length &&
            offsets[index] + heights[index] <= pageStart) {
          index++;
        }
        continue;
      }

      // A forced break ends the page wherever it falls, even mid-run (9.3).
      // Applied before the keep-with-next pull-back, because a break is a hard
      // constraint and stranding rules are a preference.
      for (var i = index; i <= lastFitting; i++) {
        if (blocks[i] is DocPageBreak) {
          lastFitting = i;
          break;
        }
      }

      // Do not strand a heading: if the last block that fits wants to keep its
      // follower, push it to the next page too.
      while (lastFitting > index && blocks[lastFitting].keepWithNext) {
        lastFitting--;
      }

      final end = offsets[lastFitting] + heights[lastFitting];
      slices.add(PageSlice(offsetY: pageStart, height: end - pageStart));

      index = lastFitting + 1;
      pageStart = end;
    }

    if (slices.isEmpty) {
      slices.add(PageSlice(offsetY: 0, height: totalHeight));
    }
    return slices;
  }

  /// Usable content height on a page, after margins.
  static double contentHeight(PageSpec page, TemplateStyle style) =>
      page.height - style.margin * 2;
}
