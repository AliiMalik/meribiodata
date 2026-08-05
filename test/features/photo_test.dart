import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/features/photo/exif_scanner.dart';
import 'package:meribiodata/features/photo/photo_processor.dart';
import 'package:meribiodata/features/photo/photo_store.dart';

/// 9.3. The requirement this file exists for is one sentence long — a photo
/// must leave the app carrying no record of where it was taken — and it is
/// invisible to anyone looking at the picture. So it is asserted on the bytes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExifScanner', () {
    test('a bare JPEG with only a JFIF header is clean', () {
      // APP0/JFIF is the density header every encoder writes and holds nothing
      // personal. Flagging it would make the check useless.
      expect(ExifScanner.hasPrivateMetadata(_jpeg(app0: true)), isFalse);
      expect(ExifScanner.markers(_jpeg(app0: true)), contains(0xE0));
    });

    test('an APP1 EXIF segment is caught', () {
      final bytes = _jpeg(app0: true, segments: {0xE1: _exifWithGps()});
      expect(ExifScanner.hasPrivateMetadata(bytes), isTrue);
      expect(ExifScanner.describe(bytes), 'APP1');
    });

    test('a Photoshop block and a comment are caught too', () {
      final bytes = _jpeg(
        segments: {
          0xED: Uint8List.fromList([1, 2, 3]),
          0xFE: Uint8List.fromList('Taken at home'.codeUnits),
        },
      );
      expect(ExifScanner.describe(bytes), 'APP13, COM');
    });

    test('scanning stops at the start of scan', () {
      // 0xFF 0xE1 inside compressed pixel data is a coincidence, not a
      // segment. Reading past SOS would report metadata on a clean file.
      final bytes = _jpeg(
        app0: true,
        scanData: Uint8List.fromList([0xFF, 0xE1, 0x00, 0x08, 1, 2, 3, 4]),
      );
      expect(ExifScanner.hasPrivateMetadata(bytes), isFalse);
    });

    test('a non-JPEG reports nothing rather than throwing', () {
      expect(ExifScanner.markers(Uint8List.fromList([1, 2, 3, 4])), isEmpty);
      expect(ExifScanner.markers(Uint8List(0)), isEmpty);
    });

    test('a truncated segment length terminates the scan', () {
      // Malformed input must not spin: a length below 2 cannot include its own
      // length bytes, so the cursor would never advance.
      final bytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x00]);
      expect(ExifScanner.markers(bytes), [0xE1]);
    });
  });

  group('PhotoProcessor', () {
    // The real encoder is a platform channel. Passing the PNG through
    // unchanged keeps the pixel pipeline — the part that does the stripping —
    // under test without one.
    final processor = PhotoProcessor(encodeJpeg: (png, _) async => png);

    test('a real photo carrying GPS comes out with none of it', () async {
      // A genuine JPEG written by an imaging library, with an EXIF block
      // holding a camera make and a latitude/longitude in Lahore — the shape
      // of every photo taken on a phone.
      final source = File(
        'test/support/photo_with_gps.jpg',
      ).readAsBytesSync();

      expect(
        ExifScanner.hasPrivateMetadata(source),
        isTrue,
        reason: 'the fixture must really carry metadata to be worth a test',
      );
      expect(_contains(source, 'MERI-TEST-CAMERA'), isTrue);
      expect(_contains(source, 'Exif\x00\x00'), isTrue);

      final processed = await processor.process(source);

      expect(_contains(processed, 'MERI-TEST-CAMERA'), isFalse);
      expect(_contains(processed, 'Exif\x00\x00'), isFalse);

      // The stronger claim, and the one the design rests on: not that the
      // metadata was stripped out, but that the source file was never copied.
      // The output is drawn from decoded pixels, so it cannot share a run.
      expect(_sharesLongRun(source, processed), isFalse);
    });

    test('the JPEG the app actually writes is checked at runtime', () {
      // The final encode is a platform channel and cannot run here, so the
      // guarantee is asserted inside process() on every debug build instead.
      // This pins the oracle that assertion uses.
      final withExif = _jpeg(app0: true, segments: {0xE1: _exifWithGps()});
      expect(ExifScanner.hasPrivateMetadata(withExif), isTrue);
      expect(ExifScanner.hasPrivateMetadata(_jpeg(app0: true)), isFalse);
    });

    test('crops to the requested rectangle', () async {
      final source = await _encodeSolid(1000, 1000, const Color(0xFF112233));

      final processed = await processor.process(
        source,
        crop: const Rect.fromLTWH(0.25, 0, 0.5, 1),
      );

      final size = await _sizeOf(processed);
      expect(size.width / size.height, closeTo(0.5, 0.01));
    });

    test(
      'rotation swaps the dimensions the crop is measured against',
      () async {
        final source = await _encodeSolid(800, 400, const Color(0xFF112233));

        // Portrait after a quarter turn, so a full-frame crop is 400x800.
        final processed = await processor.process(source, quarterTurns: 1);

        final size = await _sizeOf(processed);
        expect(size.width / size.height, closeTo(0.5, 0.01));
      },
    );

    test(
      'caps the long edge, so a 12 MP photo does not go into a backup',
      () async {
        final source = await _encodeSolid(3000, 2000, const Color(0xFF112233));

        final size = await _sizeOf(await processor.process(source));

        expect(size.width, PhotoProcessor.longEdge);
        expect(size.height, (PhotoProcessor.longEdge * 2 / 3).round());
      },
    );

    test('a small photo is not upscaled into false detail', () async {
      final source = await _encodeSolid(300, 400, const Color(0xFF112233));

      final size = await _sizeOf(await processor.process(source));

      expect(size.width, 300);
      expect(size.height, 400);
    });

    test(
      'a crop reaching outside the image is clipped, not stretched',
      () async {
        final source = await _encodeSolid(400, 400, const Color(0xFF112233));

        final processed = await processor.process(
          source,
          crop: const Rect.fromLTWH(0.5, 0.5, 1, 1),
        );

        final size = await _sizeOf(processed);
        expect(size.width, 200);
        expect(size.height, 200);
      },
    );
  });

  group('PhotoStore', () {
    late Directory root;
    late PhotoStore store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('photo-store-test');
      store = PhotoStore(base: () async => root);
    });

    tearDown(() async {
      if (root.existsSync()) await root.delete(recursive: true);
    });

    test(
      'saves under photos/, never beside the exports the app shares',
      () async {
        final path = await store.save(Uint8List.fromList([1, 2, 3]));

        // exports/ is the only directory file_paths.xml lets the FileProvider
        // hand to another app. A photo landing there would be reachable by any
        // app the user shares to.
        expect(path, startsWith('${PhotoStore.directoryName}/'));
        expect(path, isNot(contains('exports')));
        expect(await store.read(path), [1, 2, 3]);
      },
    );

    test(
      'stores a relative path, so a restored profile still resolves',
      () async {
        final path = await store.save(Uint8List.fromList([9]));

        expect(path, isNot(contains(root.path)));

        // The same relative path against a different device's app directory.
        final moved = await Directory.systemTemp.createTemp(
          'photo-store-moved',
        );
        addTearDown(() async => moved.delete(recursive: true));
        final elsewhere = PhotoStore(base: () async => moved);
        await elsewhere.writeAt(path, Uint8List.fromList([9]));

        expect(await elsewhere.read(path), [9]);
      },
    );

    test('a missing file reads as null rather than as an error', () async {
      expect(await store.read('photos/gone.jpg'), isNull);
      expect(await store.read(null), isNull);
      expect(await store.read(''), isNull);
    });

    test('deleting is idempotent', () async {
      final path = await store.save(Uint8List.fromList([1]));
      await store.delete(path);
      await store.delete(path);
      expect(await store.read(path), isNull);
    });
  });
}

// --- Fixtures --------------------------------------------------------------

/// Builds a syntactically valid JPEG shell with the segments asked for.
Uint8List _jpeg({
  bool app0 = false,
  Map<int, Uint8List> segments = const {},
  Uint8List? scanData,
}) {
  final bytes = BytesBuilder()..add([0xFF, 0xD8]);

  void segment(int marker, List<int> payload) {
    final length = payload.length + 2;
    bytes.add([0xFF, marker, (length >> 8) & 0xFF, length & 0xFF, ...payload]);
  }

  if (app0) segment(0xE0, [...'JFIF'.codeUnits, 0, 1, 1, 0, 0, 1, 0, 1, 0, 0]);
  segments.forEach(segment);

  bytes
    ..add([0xFF, 0xDA, 0x00, 0x08, 1, 1, 0, 0, 0x3F, 0])
    ..add(scanData ?? Uint8List.fromList([0x00]))
    ..add([0xFF, 0xD9]);

  return bytes.toBytes();
}

/// The header of a real EXIF APP1 payload, with a GPS IFD pointer tag. Enough
/// structure that the scanner is looking at the shape it will meet in the wild.
Uint8List _exifWithGps() => Uint8List.fromList([
  ...'Exif'.codeUnits, 0x00, 0x00,
  0x4D, 0x4D, 0x00, 0x2A, // big-endian TIFF header
  0x00, 0x00, 0x00, 0x08,
  0x00, 0x01, // one entry
  0x88, 0x25, // GPSInfo IFD pointer
  0x00, 0x04, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x1A,
]);

Future<Uint8List> _encodeSolid(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();

  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<ui.Size> _sizeOf(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  final size = ui.Size(image.width.toDouble(), image.height.toDouble());
  image.dispose();
  return size;
}

bool _contains(Uint8List haystack, String needle) =>
    String.fromCharCodes(haystack).contains(needle);

/// True when [b] contains any 32-byte run from [a]. A re-encode from pixels
/// cannot reproduce one; copying the file can only produce them.
bool _sharesLongRun(Uint8List a, Uint8List b) {
  const window = 32;
  if (a.length < window || b.length < window) return false;

  final needles = <String>{};
  for (var i = 0; i + window <= a.length; i += window) {
    needles.add(String.fromCharCodes(a.sublist(i, i + window)));
  }
  for (var i = 0; i + window <= b.length; i++) {
    if (needles.contains(String.fromCharCodes(b.sublist(i, i + window)))) {
      return true;
    }
  }
  return false;
}
