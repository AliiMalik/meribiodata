import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/domain/render/decorated_templates.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/features/export/export_service.dart';
import 'package:path_provider/path_provider.dart';

import '../test/support/document_fixtures.dart';

/// The on-device half of the export tests.
///
/// `test/features/export_publish_test.dart` covers the Dart rules — partial
/// saves, the missing-channel fallback — against a *mocked* method channel. It
/// cannot execute a single line of `MainActivity.kt`, so until this file ran,
/// the MediaStore insert had never executed anywhere at all.
///
/// Run against a connected phone:
///
/// ```bash
/// flutter test integration_test/export_publish_on_device_test.dart -d <id>
/// ```
///
/// ## Why most of this does not render anything
///
/// The subject under test is the Kotlin, and a file's bytes are irrelevant to
/// it. Feeding `publish` plain files instead of real exports makes these tests
/// fast, deterministic, and able to cover the branches that matter — Downloads
/// versus Pictures, a source that cannot be read, a multi-page save where one
/// page fails.
///
/// One test does export for real, end to end, so the whole chain is covered
/// once. It uses English, which takes the vector PDF path. The raster path
/// deliberately is not exercised here: `DocumentExporter.renderPages` mounts
/// the page in an off-screen `Overlay` and waits for it to paint, and the test
/// binding does not drive frames while an `await` is outstanding, so it hangs
/// rather than fails. That path is covered by the golden tests on the host;
/// seeing Perso-Arabic shaped by the phone's own text stack still needs a
/// human with the app open.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const service = ExportService();

  /// A real file in the app's private storage, exactly where an export lands.
  Future<File> scratchFile(String name, {int bytes = 4096}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(
      Uint8List.fromList(List.generate(bytes, (i) => i % 256)),
    );
    return file;
  }

  // `bytes` is summed defensively: two of these tests pass a path that does not
  // exist on purpose, and statting it would fail the test in the helper before
  // `publish` was ever called.
  ExportResult resultOf(List<File> files) => ExportResult(
    files: files,
    pageCount: files.length,
    bytes: files.fold(
      0,
      (sum, f) => sum + (f.existsSync() ? f.lengthSync() : 0),
    ),
    elapsed: Duration.zero,
  );

  group('MediaStore publishing, on the device that has to do it', () {
    testWidgets('a PDF lands in Downloads', (tester) async {
      final file = await scratchFile('probe-downloads.pdf');

      final published = await service.publish(
        resultOf([file]),
        mimeType: 'application/pdf',
      );

      expect(
        published,
        isTrue,
        reason: 'MediaStore insert into Downloads failed on this device',
      );
    });

    testWidgets('an image lands in Pictures', (tester) async {
      final file = await scratchFile('probe-pictures.jpg');

      final published = await service.publish(
        resultOf([file]),
        mimeType: 'image/jpeg',
      );

      expect(published, isTrue);
    });

    testWidgets('every page of a multi-page save lands', (tester) async {
      final files = [
        for (var i = 1; i <= 3; i++) await scratchFile('probe-multi-$i.jpg'),
      ];

      final published = await service.publish(
        resultOf(files),
        mimeType: 'image/jpeg',
      );

      expect(published, isTrue);
    });

    testWidgets('a source that cannot be read fails, and leaves nothing '
        'behind', (tester) async {
      // The native side must return null rather than create a MediaStore row
      // it never wrote bytes into — that row would show up in the Files app as
      // a download that opens to nothing.
      final published = await service.publish(
        resultOf([File('/data/local/tmp/definitely-not-here.pdf')]),
        mimeType: 'application/pdf',
      );

      expect(published, isFalse);
    });

    testWidgets('a partial save is not reported as a save, and takes back '
        'the page that did land', (tester) async {
      final good = await scratchFile('probe-partial-1.jpg');
      final missing = File('/data/local/tmp/also-not-here.jpg');

      final published = await service.publish(
        resultOf([good, missing]),
        mimeType: 'image/jpeg',
      );

      // Telling somebody their biodata is in their gallery when one page of
      // two arrived is worse than telling them it failed: they find out when
      // they go to send it.
      expect(published, isFalse);

      // The first run of this test on a real phone reported false and left
      // probe-partial-1.jpg in Pictures anyway; the rollback in publish() is
      // there because of it. That the row is really gone is checked from the
      // host afterwards, rather than by adding a MediaStore query to the app
      // that only a test would ever call:
      //
      //   adb shell content query --uri content://media/external/file \
      //     --projection _display_name --where "_display_name LIKE 'probe-%'"
    });

    testWidgets('an export of nothing is not a save', (tester) async {
      final published = await service.publish(
        const ExportResult(
          files: [],
          pageCount: 0,
          bytes: 0,
          elapsed: Duration.zero,
        ),
        mimeType: 'application/pdf',
      );

      expect(published, isFalse);
    });
  });

  testWidgets('a real biodata exports and publishes, end to end', (
    tester,
  ) async {
    final labels = await BundledLabels.load();

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (inner) {
            context = inner;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final result = await service.exportPdf(
      // The widget was pumped by this test and is still mounted.
      // ignore: use_build_context_synchronously
      context: context,
      document: sampleDocument('en', labels: labels),
      template: DecoratedTemplates.all.first,
      page: PageSpec.a4,
      fileName: 'ondevice-en',
    );

    expect(result.files.single.existsSync(), isTrue);
    expect(result.files.single.lengthSync(), greaterThan(1000));

    final published = await service.publish(
      result,
      mimeType: 'application/pdf',
    );

    expect(published, isTrue);

    debugPrint(
      'PUBLISHED ondevice-en.pdf: ${result.files.single.lengthSync()} bytes, '
      '${result.pageCount} page(s), ${result.elapsed.inMilliseconds}ms',
    );
  });
}
