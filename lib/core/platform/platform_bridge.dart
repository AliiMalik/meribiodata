import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The one thing this app asks the Android platform for directly (9.1).
///
/// It exists because `share_plus` cannot target a specific app, and a biodata
/// in Pakistan travels on WhatsApp more than by any other route.
///
/// A document picker used to live here too, for choosing a `.mbd` backup file.
/// Drive sync replaced that flow, so it went with it rather than staying as
/// code nothing calls.
///
/// Every method degrades to a null or false result rather than throwing, so
/// callers always have a sensible fallback.
class PlatformBridge {
  const PlatformBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'safarnamastudios.meribiodata.app/platform';

  final MethodChannel _channel;

  /// Whether WhatsApp (consumer or business) is installed.
  Future<bool> isWhatsAppAvailable() async =>
      await _invoke<bool>('isWhatsAppAvailable') ?? false;

  /// Returns false when WhatsApp is missing or refused the intent, which is
  /// the caller's cue to use the share sheet instead.
  Future<bool> shareToWhatsApp({
    required List<File> files,
    required String mimeType,
    String? text,
  }) async {
    if (files.isEmpty) return false;
    return await _invoke<bool>('shareToWhatsApp', {
          'paths': [for (final file in files) file.path],
          'mimeType': mimeType,
          'text': text,
        }) ??
        false;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('Platform call $method failed: $error');
      return null;
    } on MissingPluginException {
      // Widget tests and any platform without the channel registered.
      return null;
    }
  }
}
