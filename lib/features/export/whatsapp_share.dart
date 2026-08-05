import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shares files straight to WhatsApp (9.1).
///
/// In Pakistan a biodata circulates on WhatsApp far more than by email or as a
/// PDF attachment, so the app targets it directly rather than dropping the user
/// into a generic chooser. `share_plus` cannot target a package, hence the
/// platform channel.
///
/// Every method degrades to "not available" rather than throwing, so the caller
/// can fall back to the ordinary share sheet.
class WhatsAppShare {
  const WhatsAppShare({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'safarnamastudios.meribiodata.app/whatsapp';

  final MethodChannel _channel;

  /// Whether WhatsApp (consumer or business) is installed.
  ///
  /// No explicit platform check: anywhere the channel is not registered throws
  /// [MissingPluginException], which is handled below and means the same thing.
  /// A `Platform.isAndroid` guard would only make this untestable off-device.
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on PlatformException catch (error) {
      debugPrint('WhatsApp availability check failed: $error');
      return false;
    } on MissingPluginException {
      // Widget tests and any future platform without the channel.
      return false;
    }
  }

  /// Returns false when WhatsApp is missing or refused the intent, which is
  /// the caller's cue to use the share sheet instead.
  Future<bool> share({
    required List<File> files,
    required String mimeType,
    String? text,
  }) async {
    if (files.isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>('share', {
            'paths': [for (final file in files) file.path],
            'mimeType': mimeType,
            'text': text,
          }) ??
          false;
    } on PlatformException catch (error) {
      debugPrint('WhatsApp share failed: $error');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
