import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What this app asks the Android platform for directly.
///
/// **WhatsApp share (9.1)**, because `share_plus` cannot target a specific app
/// and a biodata in Pakistan travels on WhatsApp more than by any other route.
///
/// **Publishing an export**, because a file written to app-private storage can
/// be handed to another app through a FileProvider grant but can never be
/// found by the person who saved it, and disappears when the app is
/// uninstalled.
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

  /// Copies [file] into the user's Downloads (documents) or Pictures (images).
  ///
  /// Returns the visible file name on success, or null when the copy could not
  /// be made — which callers must treat as "not saved" rather than glossing
  /// over it. Null is also what Android 9 and older return: publishing to a
  /// public folder there needs a permission to read and write *all* the user's
  /// files, which is an absurd thing for this app to ask for, so those versions
  /// are pointed at the share sheet instead.
  Future<String?> saveToGallery({
    required File file,
    required String mimeType,
  }) => _invoke<String>('saveToGallery', {
    'path': file.path,
    'mimeType': mimeType,
  });

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
