import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/domain/render/doc_block.dart';
import 'package:meribiodata/features/export/render/paginator.dart';

void main() {
  List<PageSlice> paginate(
    List<DocBlock> blocks,
    List<double> heights, {
    double pageHeight = 100,
  }) => Paginator.paginate(
    blocks: blocks,
    heights: heights,
    pageHeight: pageHeight,
  );

  DocRow row() => const DocRow(label: 'L', value: 'V');

  test('content that fits produces a single page', () {
    final slices = paginate([row(), row()], [30, 30]);

    expect(slices.length, 1);
    expect(slices.single.offsetY, 0);
    expect(slices.single.height, 60);
  });

  test('content that overflows breaks between blocks, never inside one', () {
    final slices = paginate([row(), row(), row(), row()], [40, 40, 40, 40]);

    expect(slices.length, 2);
    expect(slices[0].offsetY, 0);
    expect(slices[0].height, 80);
    expect(slices[1].offsetY, 80);
    expect(slices[1].height, 80);
  });

  test('every block lands on exactly one page', () {
    final heights = List.filled(20, 33.5);
    final blocks = List.generate(20, (_) => row());

    final slices = paginate(blocks, heights);
    final covered = slices.fold<double>(0, (sum, s) => sum + s.height);

    expect(covered, closeTo(20 * 33.5, 0.001));
    // Slices are contiguous — no content skipped, none rendered twice.
    for (var i = 1; i < slices.length; i++) {
      expect(
        slices[i].offsetY,
        closeTo(
          slices[i - 1].offsetY + slices[i - 1].height,
          0.001,
        ),
      );
    }
  });

  test('a section heading is never stranded at the foot of a page', () {
    // 60 + 35 fits in 100, but the heading wants its first row with it.
    final blocks = [row(), const DocSectionTitle('Family'), row()];
    final slices = paginate(blocks, [60, 35, 30]);

    // The heading is pushed to page two rather than left alone on page one.
    expect(slices.length, 2);
    expect(slices[0].height, 60);
    expect(slices[1].offsetY, 60);
  });

  test('a block taller than a page splits rather than looping', () {
    final slices = paginate([row(), row()], [250, 20]);

    expect(slices.length, greaterThan(1));
    expect(slices.first.height, 100);
    // Terminates and covers everything.
    expect(
      slices.last.offsetY + slices.last.height,
      greaterThanOrEqualTo(250),
    );
  });

  test('an empty document still produces one page', () {
    expect(paginate(const [], const []).length, 1);
  });

  test('the 60-field case paginates instead of clipping (§6.3)', () {
    // 60 rows plus 10 section headings, on A4 content height.
    final blocks = <DocBlock>[];
    final heights = <double>[];
    for (var section = 0; section < 10; section++) {
      blocks.add(DocSectionTitle('Section $section'));
      heights.add(20);
      for (var field = 0; field < 6; field++) {
        blocks.add(row());
        heights.add(26);
      }
    }

    final slices = paginate(blocks, heights, pageHeight: 746);

    expect(slices.length, greaterThan(1));
    final covered = slices.fold<double>(0, (sum, s) => sum + s.height);
    expect(covered, closeTo(heights.fold<double>(0, (a, b) => a + b), 0.001));
  });
}
