import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/features/export/plain_text.dart';

import '../support/document_fixtures.dart';

void main() {
  late BundledLabels labels;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    labels = await BundledLabels.load();
  });

  group('the biodata as text (#35)', () {
    test('carries the title, sections and every field', () {
      final text = documentAsPlainText(sampleDocument('en', labels: labels));

      final document = sampleDocument('en', labels: labels);
      expect(text, contains(document.title));
      for (final section in document.nonEmptySections) {
        expect(text, contains(section.title));
        for (final field in section.fields) {
          expect(
            text,
            contains(field.label),
            reason: '${field.label} is missing from the text export',
          );
        }
      }
    });

    test('Shareable masking applies exactly as it does to the PDF', () {
      final full = documentAsPlainText(sampleDocument('en', labels: labels));
      final shareable = documentAsPlainText(
        sampleDocument('en', labels: labels, mode: ExportMode.shareable),
      );

      // The failure this guards against is a text path that reads the raw
      // profile and quietly reintroduces the one mistake the app exists to
      // prevent: a phone number and home address pasted into a group chat.
      expect(full, contains('1234567'));
      expect(shareable, isNot(contains('1234567')));
      expect(shareable, isNot(contains('House 12')));
      expect(shareable.length, lessThan(full.length));
    });

    test('the watermark follows the document, not the format', () {
      final free = sampleDocument('en', labels: labels);
      expect(free.watermark, isNotNull);
      expect(documentAsPlainText(free), contains(free.watermark));

      // Premium suppresses the watermark by passing null, and the text share
      // must not reintroduce a credit the user paid to remove.
      final premium = RenderedDocument(
        title: free.title,
        sections: free.sections,
        language: free.language,
        digitStyle: free.digitStyle,
        mode: free.mode,
      );
      expect(
        documentAsPlainText(premium),
        isNot(contains('MeriBiodata')),
      );
    });

    test('an empty biodata still produces something sendable', () {
      final document = sampleDocument('en', labels: labels);
      final empty = RenderedDocument(
        title: document.title,
        sections: const [],
        language: document.language,
        digitStyle: document.digitStyle,
        mode: ExportMode.full,
      );

      final text = documentAsPlainText(empty);
      expect(text, document.title);
      expect(text.trim(), isNotEmpty);
    });

    test('Urdu keeps the isolate marks the renderer relies on', () {
      final text = documentAsPlainText(sampleDocument('ur', labels: labels));

      // Values are isolated when the document is built, so text inherits it.
      // Without these a phone number inside an Urdu line reverses in a chat
      // app exactly as it would in a PDF.
      // Escaped rather than written literally: an invisible direction mark in
      // source is exactly the kind of thing the analyzer refuses, and rightly.
      const leftToRightIsolate = '\u2066';
      const rightToLeftIsolate = '\u2067';
      expect(
        text.contains(leftToRightIsolate) || text.contains(rightToLeftIsolate),
        isTrue,
        reason: 'no bidi isolate survived into the text export',
      );
    });
  });
}
