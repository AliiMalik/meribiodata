import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/platform/platform_bridge.dart';

/// The bridge is the only place in the app that talks to Android directly, so
/// the contract worth pinning is the *shape of the call* and, more importantly,
/// that nothing it does can throw into a caller. A backup restore that crashes
/// because the user tapped Back in the file picker would be a data-loss-shaped
/// bug caused by a non-event.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('safarnamastudios.meribiodata.app/platform');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  MethodCall? lastCall;

  void respond(Object? Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      lastCall = call;
      return handler(call);
    });
  }

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    lastCall = null;
  });

  group('shareToWhatsApp', () {
    test('sends the file paths and mime type the platform expects', () async {
      respond((_) => true);

      final sent = await const PlatformBridge().shareToWhatsApp(
        files: [File('/tmp/a.jpg'), File('/tmp/b.jpg')],
        mimeType: 'image/jpeg',
        text: 'Biodata',
      );

      expect(sent, isTrue);
      expect(lastCall?.method, 'shareToWhatsApp');
      expect(lastCall?.arguments, {
        'paths': ['/tmp/a.jpg', '/tmp/b.jpg'],
        'mimeType': 'image/jpeg',
        'text': 'Biodata',
      });
    });

    test('never calls the platform with an empty file list', () async {
      respond((_) => true);

      final sent = await const PlatformBridge().shareToWhatsApp(
        files: [],
        mimeType: 'image/jpeg',
      );

      expect(sent, isFalse);
      expect(lastCall, isNull);
    });

    test('reports false when the platform refuses, so the caller can fall '
        'back to the share sheet', () async {
      respond((_) => false);

      expect(
        await const PlatformBridge().shareToWhatsApp(
          files: [File('/tmp/a.jpg')],
          mimeType: 'image/jpeg',
        ),
        isFalse,
      );
    });
  });

  group('openDocument', () {
    test('returns the chosen bytes', () async {
      respond((_) => Uint8List.fromList([1, 2, 3]));

      expect(
        await const PlatformBridge().openDocument(),
        Uint8List.fromList([1, 2, 3]),
      );
    });

    test('returns null when the user cancels', () async {
      respond((_) => null);

      expect(await const PlatformBridge().openDocument(), isNull);
    });

    test(
      'swallows a platform error rather than throwing at the caller',
      () async {
        respond((_) => throw PlatformException(code: 'read_failed'));

        expect(await const PlatformBridge().openDocument(), isNull);
      },
    );
  });

  test('every method degrades quietly with no channel registered', () async {
    // The state in a widget test, and on any platform that is not Android.
    const bridge = PlatformBridge();

    expect(await bridge.isWhatsAppAvailable(), isFalse);
    expect(await bridge.openDocument(), isNull);
    expect(
      await bridge.shareToWhatsApp(
        files: [File('/tmp/a.jpg')],
        mimeType: 'image/jpeg',
      ),
      isFalse,
    );
  });
}
