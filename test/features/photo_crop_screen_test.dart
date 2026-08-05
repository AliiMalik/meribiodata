import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/features/photo/photo_crop_screen.dart';
import 'package:meribiodata/features/photo/photo_processor.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';

/// The crop screen's whole job is to turn a gesture into one rectangle. If that
/// rectangle is wrong the photo is silently destroyed — which is exactly what
/// happened on a device: a stored photo came back 1x1 pixels.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> png(int width, int height) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF335599),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  testWidgets('a photo saved without adjustment keeps its whole frame', (
    tester,
  ) async {
    final source = await tester.runAsync(() => png(240, 320));

    Rect? requested;
    final probe = _ProbeProcessor((crop, turns) => requested = crop);

    // The screen decodes its preview off the platform thread, so the pump has
    // to be a real one; a spinner also never settles.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: const [Locale('en')],
          home: PhotoCropScreen(source: source!, processor: probe),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump();

    expect(requested, isNotNull);
    // A 3:4 source in a 3:4 frame is the whole image, give or take rounding.
    expect(requested!.width, closeTo(1, 0.01));
    expect(requested!.height, closeTo(1, 0.01));
    expect(requested!.left, closeTo(0, 0.01));
    expect(requested!.top, closeTo(0, 0.01));
  });
}

/// Records the crop it was asked for and returns the source untouched.
class _ProbeProcessor extends PhotoProcessor {
  const _ProbeProcessor(this.onCrop);

  final void Function(Rect? crop, int quarterTurns) onCrop;

  @override
  Future<Uint8List> process(
    Uint8List source, {
    Rect? crop,
    int quarterTurns = 0,
  }) async {
    onCrop(crop, quarterTurns);
    return source;
  }
}
