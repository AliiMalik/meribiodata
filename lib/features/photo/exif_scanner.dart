import 'dart:typed_data';

/// One marker segment inside a JPEG.
class JpegSegment {
  const JpegSegment({
    required this.marker,
    required this.payloadStart,
    required this.payloadLength,
  });

  /// The byte after `0xFF`, e.g. `0xE1` for APP1.
  final int marker;

  final int payloadStart;
  final int payloadLength;
}

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

  static const _app0 = 0xE0;
  static const _app2 = 0xE2;
  static const _comment = 0xFE;

  /// Identifies the ICC colour profile flavour of APP2.
  static const _iccSignature = 'ICC_PROFILE';

  /// Whether a segment can carry information about a person or a place.
  ///
  /// The interesting cases are the two exceptions:
  ///
  /// **APP0** is the bare JFIF density header. It holds nothing personal and
  /// every JPEG encoder writes one, so flagging it would make this check cry
  /// wolf on its own output.
  ///
  /// **APP2 carrying an ICC profile** is colorimetry — primaries, gamma, a
  /// white point — computed from the pixel data by the encoder. Android's JPEG
  /// encoder attaches one to every image it writes, including images this app
  /// composed from scratch, so it cannot be evidence that anything survived
  /// from the source file. APP2 is shared with the FlashPix extension, which is
  /// a different animal, so the exception is made on the payload signature
  /// rather than on the marker.
  ///
  /// Everything else in APP1–APP15 (EXIF and its GPS block, XMP, the
  /// Photoshop/IPTC record) and the free-text comment stays flagged.
  static bool isPrivate(Uint8List bytes, JpegSegment segment) {
    if (segment.marker == _comment) return true;
    if (segment.marker == _app0) return false;
    if (segment.marker == _app2) return !_payloadStartsWith(bytes, segment);
    return segment.marker >= 0xE1 && segment.marker <= 0xEF;
  }

  /// True when [bytes] is a JPEG carrying at least one metadata segment.
  ///
  /// Non-JPEG input returns false: PNG output from the engine's encoder has no
  /// text chunks to begin with, and this is a JPEG-shaped question.
  static bool hasPrivateMetadata(Uint8List bytes) =>
      segments(bytes).any((s) => isPrivate(bytes, s));

  /// Every segment in the file, in order, up to the start of scan.
  ///
  /// Stops at SOS because everything after it is entropy-coded pixel data, in
  /// which a `0xFF 0xE1` byte pair is a coincidence rather than a segment.
  static List<JpegSegment> segments(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != _soi) {
      return const [];
    }

    final found = <JpegSegment>[];
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

      // Standalone markers (RST0-7, TEM) carry no length field.
      if ((marker >= 0xD0 && marker <= 0xD7) || marker == 0x01) {
        found.add(
          JpegSegment(
            marker: marker,
            payloadStart: cursor + 1,
            payloadLength: 0,
          ),
        );
        i = cursor + 1;
        continue;
      }

      final length = (bytes[cursor + 1] << 8) | bytes[cursor + 2];
      found.add(
        JpegSegment(
          marker: marker,
          payloadStart: cursor + 3,
          // The declared length includes its own two bytes.
          payloadLength: length - 2,
        ),
      );

      // A length below 2 cannot include its own length bytes, so the file is
      // malformed; stop rather than loop forever on a zero-width segment.
      if (length < 2) return found;
      i = cursor + 1 + length;
    }

    return found;
  }

  static List<int> markers(Uint8List bytes) => [
    for (final segment in segments(bytes)) segment.marker,
  ];

  /// A human-readable list for a debug assertion message.
  static String describe(Uint8List bytes) => [
    for (final segment in segments(bytes))
      if (isPrivate(bytes, segment)) _name(segment.marker),
  ].join(', ');

  static String _name(int marker) =>
      marker == _comment ? 'COM' : 'APP${marker - 0xE0}';

  static bool _payloadStartsWith(Uint8List bytes, JpegSegment segment) {
    final end = segment.payloadStart + _iccSignature.length;
    if (segment.payloadLength < _iccSignature.length || end > bytes.length) {
      return false;
    }
    for (var i = 0; i < _iccSignature.length; i++) {
      if (bytes[segment.payloadStart + i] != _iccSignature.codeUnitAt(i)) {
        return false;
      }
    }
    return true;
  }
}
