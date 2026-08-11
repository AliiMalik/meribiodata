// The context comes from a widget this test pumped itself and never unmounts,
// so the across-async-gap warning does not apply here.
// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/domain/render/decorated_templates.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/features/export/export_service.dart';

import '../test/support/document_fixtures.dart';

/// The on-device half of the export tests.
///
/// `test/features/export_publish_test.dart` covers the Dart rules — partial
/// saves, the missing-channel fallback — against a mocked method channel. It
/// cannot execute a single line of `MainActivity.kt`, so the MediaStore insert
/// itself has never run anywhere. This does that, on real Android.
///
/// It also exports each language for real, which is the only way to see
/// Perso-Arabic shaped by the device's own text stack rather than by the host
/// machine the goldens were captured on.
///
/// Run against a connected phone:
///
/// ```bash
/// flutter test integration_test/export_publish_on_device_test.dart -d <id>
/// ```
///
/// The files it publishes are left in Downloads and Pictures deliberately: the
/// point is to go and look at them, and to confirm they are reachable from the
/// Files app the way any other download is.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late BundledLabels labels;

  setUpAll(() async {
    labels = await BundledLabels.load();
  });

  /// A real BuildContext, sized like a phone. The exporter needs one, and a
  /// document rendered without a real view would not exercise the same code.
  Future<BuildContext> contextFor(WidgetTester tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return captured;
  }

  // A decorated template, so the export also decodes a full-page background
  // image — the part that actually costs memory on a real phone.
  final template = DecoratedTemplates.all.first;

  group('a saved biodata reaches storage the user can browse', () {
    testWidgets('a PDF publishes into Downloads', (tester) async {
      final context = await contextFor(tester);
      const service = ExportService();

      final result = await service.exportPdf(
        context: context,
        document: sampleDocument('en', labels: labels),
        template: template,
        page: PageSpec.a4,
        fileName: 'ondevice-en',
      );

      expect(result.files, hasLength(1));
      expect(result.files.single.existsSync(), isTrue);

      final published = await service.publish(
        result,
        mimeType: 'application/pdf',
      );

      expect(
        published,
        isTrue,
        reason: 'MediaStore insert into Downloads failed on this device',
      );
    });

    testWidgets('images publish into Pictures, every page of them', (
      tester,
    ) async {
      final context = await contextFor(tester);
      const service = ExportService();

      final result = await service.exportImages(
        context: context,
        document: sampleDocument('en', labels: labels),
        template: template,
        page: PageSpec.a4,
        fileName: 'ondevice-en-image',
      );

      expect(result.files, isNotEmpty);

      final published = await service.publish(
        result,
        mimeType: 'image/jpeg',
      );

      expect(published, isTrue);
    });
  });

  group('every language exports on the device that will render it', () {
    for (final language in ['en', 'ur', 'sd', 'ps']) {
      testWidgets('$language exports and publishes', (tester) async {
        final context = await contextFor(tester);
        const service = ExportService();

        final result = await service.exportPdf(
          context: context,
          document: sampleDocument(language, labels: labels),
          template: template,
          page: PageSpec.a4,
          fileName: 'ondevice-$language',
        );

        expect(result.files.single.lengthSync(), greaterThan(1000));

        // A raster page that came out blank still weighs something, so size
        // alone is not proof. The check that matters is human: the published
        // file is pulled off the phone and looked at.
        final published = await service.publish(
          result,
          mimeType: 'application/pdf',
        );
        expect(published, isTrue);

        debugPrint(
          'PUBLISHED $language: ${result.files.single.path} '
          '(${result.files.single.lengthSync()} bytes, '
          '${result.pageCount} page(s), ${result.elapsed.inMilliseconds}ms)',
        );
      });
    }
  });

  testWidgets('an export of nothing is not reported as saved', (tester) async {
    const service = ExportService();

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

  testWidgets('a file that does not exist fails rather than claiming a save', (
    tester,
  ) async {
    const service = ExportService();

    // The native side must return null when it cannot read the source, not
    // create an empty MediaStore row that shows up as a broken download.
    final published = await service.publish(
      ExportResult(
        files: [File('/data/local/tmp/definitely-not-here.pdf')],
        pageCount: 1,
        bytes: 0,
        elapsed: Duration.zero,
      ),
      mimeType: 'application/pdf',
    );

    expect(published, isFalse);
  });
}
