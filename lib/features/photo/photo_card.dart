import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/core/widgets/text_prompt_dialog.dart';
import 'package:meribiodata/features/photo/photo_crop_screen.dart';
import 'package:meribiodata/features/photo/photo_processor.dart';
import 'package:meribiodata/features/photo/photo_store.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';

/// The photo control in the Form Editor (9.3).
///
/// It sits above the fields rather than among them because a photo is not a
/// field: it has no label, it is not part of the schema, and — unlike every
/// other answer — a family may reasonably decide it should never leave the
/// house. The privacy line is shown permanently rather than once, for the same
/// reason.
class PhotoCard extends StatefulWidget {
  const PhotoCard({
    required this.photoPath,
    required this.onSeparatePage,
    required this.onPhotoChanged,
    required this.onSeparatePageChanged,
    this.store = const PhotoStore(),
    this.picker,
    super.key,
  });

  final String? photoPath;
  final bool onSeparatePage;

  /// Null clears the photo.
  final ValueChanged<String?> onPhotoChanged;

  final ValueChanged<bool> onSeparatePageChanged;

  final PhotoStore store;

  /// Injected in tests; `image_picker` needs a platform behind it.
  final ImagePicker? picker;

  @override
  State<PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<PhotoCard> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(PhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoPath != widget.photoPath) unawaited(_load());
  }

  Future<void> _load() async {
    final bytes = await widget.store.read(widget.photoPath);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
    });
  }

  Future<void> _pick(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);

    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final picked = await (widget.picker ?? ImagePicker()).pickImage(
        source: source,
        // A cap on what the picker hands back, so a 108 MP phone camera does
        // not deliver 30 MB into memory on the 3 GB reference device. The real
        // resizing still happens in PhotoProcessor.
        maxWidth: 3000,
        maxHeight: 3000,
      );
      if (picked == null) {
        // The user backed out. Not an error.
        if (mounted) setState(() => _busy = false);
        return;
      }

      final source0 = await picked.readAsBytes();
      final jpeg = await navigator.push<Uint8List>(
        MaterialPageRoute(builder: (_) => PhotoCropScreen(source: source0)),
      );
      if (jpeg == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final path = await widget.store.save(jpeg);
      widget.onPhotoChanged(path);
      if (mounted) {
        setState(() {
          _bytes = jpeg;
          _busy = false;
        });
      }
    } on Object catch (error, stack) {
      debugPrint('Photo pick failed: $error\n$stack');
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoFailed)));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final l10n = AppL10n.of(context);
    final confirmed = await confirm(
      context,
      title: l10n.photoRemoveConfirmTitle,
      body: l10n.photoRemoveConfirmBody,
      confirmLabel: l10n.photoRemove,
      isDestructive: true,
    );
    if (!confirmed) return;

    // The controller deletes the file; this only drops the reference.
    widget.onPhotoChanged(null);
    if (mounted) setState(() => _bytes = null);
  }

  Future<void> _chooseSource() async {
    final l10n = AppL10n.of(context);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.photoFromGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.photoFromCamera),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;
    final hasPhoto = _bytes != null;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(
                  bytes: _bytes,
                  loading: _loading || _busy,
                  // A stored path with no file behind it: a backup made before
                  // photos were carried in one, or storage cleared by the OS.
                  missing: !_loading && !hasPhoto && widget.photoPath != null,
                  onTap: _busy ? null : _chooseSource,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.photoTitle, style: text.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.photoPrivacy,
                        style: text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          TextButton.icon(
                            onPressed: _busy ? null : _chooseSource,
                            icon: const Icon(
                              Icons.add_a_photo_outlined,
                              size: 18,
                            ),
                            label: Text(
                              hasPhoto ? l10n.photoChange : l10n.photoAdd,
                            ),
                          ),
                          if (widget.photoPath != null)
                            TextButton.icon(
                              onPressed: _busy ? null : _remove,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: Text(l10n.photoRemove),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.photoPath != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.photoSeparatePage, style: text.bodyMedium),
                subtitle: Text(
                  l10n.photoSeparatePageHint,
                  style: text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                value: widget.onSeparatePage,
                onChanged: widget.onSeparatePageChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.bytes,
    required this.loading,
    required this.missing,
    required this.onTap,
  });

  final Uint8List? bytes;
  final bool loading;
  final bool missing;
  final VoidCallback? onTap;

  static const _width = 84.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        width: _width,
        // The shape it will print at, so the editor is not quietly promising
        // a square crop the document cannot deliver.
        height: _width / PhotoProcessor.aspectRatio,
        decoration: BoxDecoration(
          color: context.colors.outlineVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        clipBehavior: Clip.antiAlias,
        child: switch ((loading, bytes, missing)) {
          (true, _, _) => const Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          (_, final Uint8List image, _) => Image.memory(
            image,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          (_, _, true) => Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Center(
              child: Text(
                l10n.photoMissing,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          _ => Center(
            child: Icon(
              Icons.person_outline,
              size: 32,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        },
      ),
    );
  }
}
