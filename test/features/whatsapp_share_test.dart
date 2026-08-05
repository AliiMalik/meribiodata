import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/features/export/whatsapp_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(
    'safarnamastudios.meribiodata.app/whatsapp',
  );

  final calls = <MethodCall>[];

  void mockChannel(Object? Function(MethodCall) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  }

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('availability', () {
    test('reports what the platform says', () async {
      mockChannel((_) => true);
      expect(await const WhatsAppShare().isAvailable(), isTrue);

      mockChannel((_) => false);
      expect(await const WhatsAppShare().isAvailable(), isFalse);
    });

    test('a platform error means unavailable, not a crash', () async {
      mockChannel((_) => throw PlatformException(code: 'boom'));

      expect(await const WhatsAppShare().isAvailable(), isFalse);
    });
  });

  group('sharing', () {
    test('passes every page path and the mime type', () async {
      mockChannel((_) => true);
      final files = [File('a-1.jpg'), File('a-2.jpg')];

      final sent = await const WhatsAppShare().share(
        files: files,
        mimeType: 'image/jpeg',
        text: 'hello',
      );

      expect(sent, isTrue);
      final args = calls.single.arguments as Map;
      // Multi-page biodatas must arrive as a set so the ordering survives.
      expect(args['paths'], ['a-1.jpg', 'a-2.jpg']);
      expect(args['mimeType'], 'image/jpeg');
      expect(args['text'], 'hello');
    });

    test('an empty file list never reaches the platform', () async {
      mockChannel((_) => true);

      expect(
        await const WhatsAppShare().share(files: [], mimeType: 'image/jpeg'),
        isFalse,
      );
      expect(calls, isEmpty);
    });

    test(
      'a refused intent returns false so the caller can fall back',
      () async {
        mockChannel((_) => false);

        expect(
          await const WhatsAppShare().share(
            files: [File('a.jpg')],
            mimeType: 'image/jpeg',
          ),
          isFalse,
        );
      },
    );

    test('a missing channel returns false rather than throwing', () async {
      // What a widget test or an unsupported platform actually sees.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      expect(
        await const WhatsAppShare().share(
          files: [File('a.jpg')],
          mimeType: 'image/jpeg',
        ),
        isFalse,
      );
    });
  });
}
