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

  /// URIs the fake platform was asked to delete again.
  late List<String> removed;

  /// What the platform will answer with, one reply per call.
  late List<String?> replies;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('publish');
    calls = [];
    removed = [];
    replies = [];

    messenger.setMockMethodCallHandler(channel, (call) async {
      final args = (call.arguments as Map).cast<String, Object?>();
      if (call.method == 'removeFromGallery') {
        removed.add(args['uri']! as String);
        return true;
      }
      if (call.method != 'saveToGallery') return null;
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
    replies = ['content://media/1'];

    final published = await service.publish(
      resultWith(1),
      mimeType: 'application/pdf',
    );

    expect(published, isTrue);
    expect(calls.single['mimeType'], 'application/pdf');
  });

  test('the mime type decides Downloads or Pictures', () async {
    replies = ['content://media/1'];

    await service.publish(resultWith(1), mimeType: 'image/jpeg');

    // The native side routes on this: images go to Pictures so they appear in
    // the gallery, everything else to Downloads.
    expect(calls.single['mimeType'], 'image/jpeg');
  });

  test('every page of a multi-page biodata is published', () async {
    replies = ['content://media/1', 'content://media/2', 'content://media/3'];

    final published = await service.publish(
      resultWith(3),
      mimeType: 'image/jpeg',
    );

    expect(published, isTrue);
    expect(calls.length, 3);
  });

  test('a partial save is not reported as a save', () async {
    // Three pages, and the second one fails.
    replies = ['content://media/1', null, 'content://media/3'];

    final published = await service.publish(
      resultWith(3),
      mimeType: 'image/jpeg',
    );

    // Telling somebody their biodata is in their gallery when two pages of
    // three arrived is worse than telling them it failed — they would find out
    // when they went to send it.
    expect(published, isFalse);
  });

  test('a partial save takes back the pages that did land', () async {
    replies = ['content://media/1', null];

    await service.publish(resultWith(3), mimeType: 'image/jpeg');

    // Found on a real phone: publish() correctly returned false while page one
    // stayed in the gallery, so the user was told the save failed and had a
    // stray page of a biodata they were told they did not have.
    expect(removed, ['content://media/1']);
  });

  test(
    'a save that fails on the first page has nothing to take back',
    () async {
      replies = [null];

      await service.publish(resultWith(2), mimeType: 'image/jpeg');

      expect(removed, isEmpty);
    },
  );

  test('a save that fully succeeds removes nothing', () async {
    replies = ['content://media/1', 'content://media/2'];

    final published = await service.publish(
      resultWith(2),
      mimeType: 'image/jpeg',
    );

    expect(published, isTrue);
    expect(removed, isEmpty);
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
