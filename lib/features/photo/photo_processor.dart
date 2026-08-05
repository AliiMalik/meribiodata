import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:meribiodata/features/photo/exif_scanner.dart';

/// Turns a JPEG into a JPEG, via [Uint8List] of PNG. Injected so the pipeline
/// can be tested without a platform channel.
typedef JpegEncoder = Future<Uint8List> Function(Uint8List png, int quality);

/// Crops, rotates, downscales and re-encodes a picked photo (9.3).
///
/// The important property is not any single step but the shape of the whole
/// thing: **no byte of the source file reaches the output.** The image is
/// decoded to pixels, those pixels are drawn onto a fresh canvas, and the
/// canvas is encoded from scratch. EXIF, GPS, the camera's serial number, an
/// editing app's history — none of it has a path through, because metadata does
/// not survive being turned into pixels.
///
/// That is a stronger guarantee than calling a "strip metadata" flag and hoping
/// the plugin honours it, and it is why [ExifScanner] only has to *check* the
/// result rather than clean it.
class PhotoProcessor {
  const PhotoProcessor({this.encodeJpeg = _compress});

  final JpegEncoder encodeJpeg;

  /// Long edge of the stored photo, in pixels.
  ///
  /// A biodata photo prints at roughly 4.5 cm tall, which is 530 px at 300 dpi.
  /// 1200 leaves room for the 300 dpi export and for a user who zooms into the
  /// preview, and keeps a stored photo around 150 KB — which matters when the
  /// whole profile has to fit in a backup file the user sends over WhatsApp.
  static const longEdge = 1200;

  /// Working size before the crop is applied. Higher than [longEdge] so
  /// cropping to a face does not resample an already-small image.
  static const workingEdge = 2000;

  static const quality = 88;

  /// Portrait, the shape every printed biodata photo is. The crop UI enforces
  /// it; the processor itself will honour whatever rectangle it is given.
  static const double aspectRatio = 3 / 4;

  /// [crop] is expressed in fractions of the image *after* [quarterTurns] is
  /// applied, which is the coordinate space the user was looking at when they
  /// framed it.
  Future<Uint8List> process(
    Uint8List source, {
    Rect? crop,
    int quarterTurns = 0,
  }) async {
    final decoded = await decodeScaled(source, longestSide: workingEdge);
    final rotated = await _rotate(decoded, quarterTurns);
    if (!identical(rotated, decoded)) decoded.dispose();

    final png = await _cropAndScale(rotated, crop);
    rotated.dispose();

    final jpeg = await encodeJpeg(png, quality);

    assert(
      !ExifScanner.hasPrivateMetadata(jpeg),
      'Processed photo still carries metadata: ${ExifScanner.describe(jpeg)}. '
      'The pipeline is meant to make this impossible.',
    );

    return jpeg;
  }

  /// Decodes at a reduced size. The engine does this during decode rather than
  /// after, so a 12 MP photo never has to exist at full size in memory — which
  /// is the difference between working and being killed on the 3 GB reference
  /// device.
  static Future<ui.Image> decodeScaled(
    Uint8List bytes, {
    required int longestSide,
  }) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);

    final longest = math.max(descriptor.width, descriptor.height);
    final scale = longest <= longestSide ? 1.0 : longestSide / longest;

    final codec = await descriptor.instantiateCodec(
      targetWidth: (descriptor.width * scale).round(),
      targetHeight: (descriptor.height * scale).round(),
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    descriptor.dispose();
    return frame.image;
  }

  static Future<ui.Image> _rotate(ui.Image source, int quarterTurns) async {
    final turns = quarterTurns % 4;
    if (turns == 0) return source;

    final swapped = turns.isOdd;
    final width = swapped ? source.height : source.width;
    final height = swapped ? source.width : source.height;

    return _record(width, height, (canvas) {
      canvas
        ..translate(width / 2, height / 2)
        ..rotate(turns * math.pi / 2)
        ..translate(-source.width / 2, -source.height / 2)
        ..drawImage(source, Offset.zero, Paint());
    });
  }

  static Future<Uint8List> _cropAndScale(ui.Image image, Rect? crop) async {
    final source = crop == null
        ? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble())
        : Rect.fromLTWH(
            crop.left * image.width,
            crop.top * image.height,
            crop.width * image.width,
            crop.height * image.height,
          ).intersect(
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
          );

    final scale = math.min<double>(
      1,
      longEdge / math.max(source.width, source.height),
    );
    final width = math.max(1, (source.width * scale).round());
    final height = math.max(1, (source.height * scale).round());

    final output = await _record(width, height, (canvas) {
      canvas.drawImageRect(
        image,
        source,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
    });

    final data = await output.toByteData(format: ui.ImageByteFormat.png);
    output.dispose();
    return data!.buffer.asUint8List();
  }

  static Future<ui.Image> _record(
    int width,
    int height,
    void Function(Canvas canvas) draw,
  ) async {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return image;
  }

  static Future<Uint8List> _compress(Uint8List png, int quality) =>
      FlutterImageCompress.compressWithList(
        png,
        quality: quality,
        // The image is already exactly the size we want; these bounds exist
        // only to stop the plugin resizing it again on our behalf.
        minWidth: 1,
        minHeight: 1,
        // Already the plugin's default. Stated anyway, because a silent
        // default is a poor place to keep the one setting that decides
        // whether a family's home coordinates travel with the photo.
        // ignore: avoid_redundant_argument_values
        keepExif: false,
      );
}
