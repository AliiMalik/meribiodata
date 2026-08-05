import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/features/photo/photo_processor.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';

/// Frames a picked photo before it is stored (9.3).
///
/// Deliberately not a free-form crop. Every printed biodata photo is portrait,
/// and the templates lay one out at a fixed shape — so the useful question is
/// "which part of this picture goes in the frame", not "what shape should the
/// frame be". A fixed frame with drag and pinch is also far easier to operate
/// one-handed than eight drag handles, which is how this will actually be used.
///
/// Returns the processed JPEG through [Navigator.pop], or null if cancelled.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({
    required this.source,
    this.processor = const PhotoProcessor(),
    super.key,
  });

  /// The picked file's bytes, untouched.
  final Uint8List source;

  final PhotoProcessor processor;

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  /// A preview-sized decode. The full-quality pass happens once, on confirm.
  ui.Image? _preview;

  int _turns = 0;

  /// Scale and offset of the image within the crop frame, in frame pixels.
  double _scale = 1;
  Offset _offset = Offset.zero;

  double _scaleAtGestureStart = 1;
  Offset _focalAtGestureStart = Offset.zero;
  Offset _offsetAtGestureStart = Offset.zero;

  Size _frame = Size.zero;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final image = await PhotoProcessor.decodeScaled(
        widget.source,
        longestSide: 1400,
      );
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _preview = image);
    } on Object catch (error, stack) {
      debugPrint('Photo decode failed: $error\n$stack');
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// Size of the image as the user sees it now, before scale.
  Size get _rotatedSize {
    final image = _preview!;
    return _turns.isOdd
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
  }

  /// The scale at which the image exactly covers the frame — the floor, so a
  /// gap can never open at an edge and produce a photo with a white band.
  double get _minScale {
    final size = _rotatedSize;
    return math.max(_frame.width / size.width, _frame.height / size.height);
  }

  void _fit() {
    final size = _rotatedSize;
    _scale = _minScale;
    _offset = Offset(
      (_frame.width - size.width * _scale) / 2,
      (_frame.height - size.height * _scale) / 2,
    );
  }

  /// Keeps the image covering the frame after any pan or pinch.
  Offset _clamp(Offset offset, double scale) {
    final size = _rotatedSize;
    final width = size.width * scale;
    final height = size.height * scale;
    return Offset(
      offset.dx.clamp(math.min(0, _frame.width - width), 0),
      offset.dy.clamp(math.min(0, _frame.height - height), 0),
    );
  }

  void _onScaleStart(ScaleStartDetails details) {
    _scaleAtGestureStart = _scale;
    _focalAtGestureStart = details.localFocalPoint;
    _offsetAtGestureStart = _offset;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final scale = (_scaleAtGestureStart * details.scale).clamp(
      _minScale,
      _minScale * 6,
    );

    // Zoom about the pinch centre rather than the top-left corner, so the part
    // of the face under the fingers stays under the fingers.
    final ratio = scale / _scaleAtGestureStart;
    final anchored =
        _focalAtGestureStart -
        (_focalAtGestureStart - _offsetAtGestureStart) * ratio;
    final panned = anchored + (details.localFocalPoint - _focalAtGestureStart);

    setState(() {
      _scale = scale;
      _offset = _clamp(panned, scale);
    });
  }

  void _rotate() {
    setState(() {
      _turns = (_turns + 1) % 4;
      _fit();
    });
  }

  /// The visible rectangle, as fractions of the rotated image. This is the
  /// only value the processor needs — everything above is presentation.
  Rect get _cropFraction {
    final size = _rotatedSize;
    return Rect.fromLTWH(
      -_offset.dx / _scale / size.width,
      -_offset.dy / _scale / size.height,
      _frame.width / _scale / size.width,
      _frame.height / _scale / size.height,
    );
  }

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppL10n.of(context);
    try {
      final jpeg = await widget.processor.process(
        widget.source,
        crop: _cropFraction,
        quarterTurns: _turns,
      );
      navigator.pop(jpeg);
    } on Object catch (error, stack) {
      debugPrint('Photo processing failed: $error\n$stack');
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoFailed)));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.photoCropTitle),
        actions: [
          IconButton(
            tooltip: l10n.photoRotate,
            icon: const Icon(Icons.rotate_right),
            onPressed: _preview == null ? null : _rotate,
          ),
        ],
      ),
      body: _preview == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final frame = _frameFor(constraints.biggest);
                          if (frame != _frame) {
                            _frame = frame;
                            _fit();
                          }
                          return _CropFrame(
                            size: frame,
                            child: GestureDetector(
                              onScaleStart: _onScaleStart,
                              onScaleUpdate: _onScaleUpdate,
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: _offset.dx,
                                    top: _offset.dy,
                                    width: _rotatedSize.width * _scale,
                                    height: _rotatedSize.height * _scale,
                                    child: RotatedBox(
                                      quarterTurns: _turns,
                                      child: RawImage(
                                        image: _preview,
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Text(
                        l10n.photoCropHint,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _busy ? null : _confirm,
                          child: _busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l10n.actionSave),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// The largest portrait frame of the template's aspect ratio that fits.
  static Size _frameFor(Size available) {
    const ratio = PhotoProcessor.aspectRatio;
    final width = math.min(available.width, available.height * ratio);
    return Size(width, width / ratio);
  }
}

/// The frame itself: the crop area clipped, with everything outside it dimmed.
class _CropFrame extends StatelessWidget {
  const _CropFrame({required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(child: child),
        // A border rather than a dimmed surround: the frame is the whole
        // viewport here, so there is nothing outside it to dim.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white54, width: 2),
            ),
          ),
        ),
      ],
    ),
  );
}
