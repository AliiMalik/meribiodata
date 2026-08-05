import 'dart:typed_data';

/// Reads the segment markers out of a JPEG, so the app can *prove* a photo it
/// is about to save carries no metadata (9.3).
///
/// This matters more than it sounds. A photo straight off a phone camera
/// carries the GPS coordinates of where it was taken — for a rishta photo, that
/// is usually the family's home. That biodata then goes to a WhatsApp group of
/// people nobody in the family has met. Nothing in the picture reveals the
/// address; the bytes behind it do.
///
/// The processing pipeline strips metadata structurally, by rebuilding the
/// image from pixels rather than editing the original file. This scanner exists
/// to *check* that, in tests and in a debug assertion, rather than to do it —
/// a guarantee nobody verifies is a guarantee nobody has.
abstract final class ExifScanner {
  static const _soi = 0xD8;
  static const _eoi = 0xD9;
  static const _sos = 0xDA;

  /// Markers that can carry information about a person or a place.
  ///
  /// APP1 is EXIF (and therefore GPS) and XMP; APP13 is the Photoshop/IPTC
  /// block; COM is a free-text comment. APP0 is deliberately absent: it is the
  /// bare JFIF density header, it holds nothing personal, and every JPEG
  /// encoder in existence writes one — flagging it would make this check cry
  /// wolf on its own output.
  static bool isPrivateMarker(int marker) =>
      (marker >= 0xE1 && marker <= 0xEF) || marker == 0xFE;

  /// True when [bytes] is a JPEG carrying at least one metadata segment.
  ///
  /// Non-JPEG input returns false: PNG output from the engine's encoder has no
  /// text chunks to begin with, and this is a JPEG-shaped question.
  static bool hasPrivateMetadata(Uint8List bytes) =>
      markers(bytes).any(isPrivateMarker);

  /// Every segment marker in the file, in order, up to the start of scan.
  ///
  /// Stops at SOS because everything after it is entropy-coded pixel data, in
  /// which a `0xFF 0xE1` byte pair is a coincidence rather than a segment.
  static List<int> markers(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != _soi) {
      return const [];
    }

    final found = <int>[];
    var i = 2;

    while (i + 3 < bytes.length) {
      // Segments may be preceded by any number of 0xFF fill bytes.
      if (bytes[i] != 0xFF) return found;
      var marker = bytes[i + 1];
      var cursor = i + 1;
      while (marker == 0xFF && cursor + 1 < bytes.length) {
        marker = bytes[++cursor];
      }

      if (marker == _sos || marker == _eoi) return found;
      found.add(marker);

      // Standalone markers (RST0-7, TEM) carry no length field.
      if ((marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
        i = cursor + 1;
        continue;
      }

      final length = (bytes[cursor + 1] << 8) | bytes[cursor + 2];
      // A length below 2 cannot include its own two length bytes, so the file
      // is malformed; stop rather than loop forever on a zero-width segment.
      if (length < 2) return found;
      i = cursor + 1 + length;
    }

    return found;
  }

  /// A human-readable list for a debug assertion message.
  static String describe(Uint8List bytes) => markers(bytes)
      .where(isPrivateMarker)
      .map((m) => m == 0xFE ? 'COM' : 'APP${m - 0xE0}')
      .join(', ');
}
