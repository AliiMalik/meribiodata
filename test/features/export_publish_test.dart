import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/features/export/export_service.dart';

/// Cover for a bug a user hit: "Save as PDF" wrote into app-private storage,
/// where the file cannot be browsed to and is erased on uninstall. Saving now
/// publishes a copy through MediaStore, into Downloads or Pictures.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('safarnamastudios.meribiodata.app/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late Directory temp;
  late List<Map<String, String>> calls;

  /// What the platform will answer with, one reply per call.
  late List<String?> replies;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('publish');
    calls = [];
    replies = [];

    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'saveToGallery') return null;
      final args = (call.arguments as Map).cast<String, Object?>();
      calls.add({
        'path': args['path']! as String,
        'mimeType': args['mimeType']! as String,
      });
      return replies.isEmpty ? null : replies.removeAt(0);
    });
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    await temp.delete(recursive: true);
  });

  ExportResult resultWith(int fileCount) {
    final files = [
      for (var i = 0; i < fileCount; i++)
        File('${temp.path}/page-$i.pdf')..writeAsBytesSync([1, 2, 3]),
    ];
    return ExportResult(
      files: files,
      pageCount: fileCount,
      bytes: 3 * fileCount,
      elapsed: Duration.zero,
    );
  }

  const service = ExportService();

  test('a single file that publishes reports success', () async {
    replies = ['biodata.pdf'];

    final published = await service.publish(
      resultWith(1),
      mimeType: 'application/pdf',
    );

    expect(published, isTrue);
    expect(calls.single['mimeType'], 'application/pdf');
  });

  test('the mime type decides Downloads or Pictures', () async {
    replies = ['biodata.jpg'];

    await service.publish(resultWith(1), mimeType: 'image/jpeg');

    // The native side routes on this: images go to Pictures so they appear in
    // the gallery, everything else to Downloads.
    expect(calls.single['mimeType'], 'image/jpeg');
  });

  test('every page of a multi-page biodata is published', () async {
    replies = ['p0.jpg', 'p1.jpg', 'p2.jpg'];

    final published = await service.publish(
      resultWith(3),
      mimeType: 'image/jpeg',
    );

    expect(published, isTrue);
    expect(calls.length, 3);
  });

  test('a partial save is not reported as a save', () async {
    // Three pages, and the second one fails.
    replies = ['p0.jpg', null, 'p2.jpg'];

    final published = await service.publish(
      resultWith(3),
      mimeType: 'image/jpeg',
    );

    // Telling somebody their biodata is in their gallery when two pages of
    // three arrived is worse than telling them it failed — they would find out
    // when they went to send it.
    expect(published, isFalse);
  });

  test('a platform with no such channel fails rather than lying', () async {
    // Android 9 and older, where publishing to a public folder would need a
    // permission this app will not ask for. The caller falls back to the share
    // sheet; what it must not do is claim the file was saved.
    messenger.setMockMethodCallHandler(channel, null);

    final published = await service.publish(
      resultWith(1),
      mimeType: 'application/pdf',
    );

    expect(published, isFalse);
  });

  test('nothing to publish is not a success', () async {
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
    expect(calls, isEmpty);
  });
}
