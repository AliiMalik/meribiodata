import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/platform/platform_bridge.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/render/document_builder.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/domain/render/templates.dart';
import 'package:meribiodata/features/editor/profile_editor_controller.dart';
import 'package:meribiodata/features/export/export_service.dart';
import 'package:meribiodata/features/export/widgets/document_preview.dart';
import 'package:meribiodata/features/export/widgets/export_mode_selector.dart';
import 'package:meribiodata/features/photo/photo_store.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';

/// §7.6 — Preview & Export.
///
/// Deliberately carries **no ad banner**: the export and share buttons are the
/// highest-value taps in the app, and an ad beside them invites accidental
/// clicks, which is an AdMob policy risk rather than a mere annoyance (§8).
class ExportScreen extends StatefulWidget {
  const ExportScreen({required this.profileId, super.key});

  final String profileId;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  static const _service = ExportService();

  late final ProfileEditorController _controller = ProfileEditorController(
    context.read<ProfileRepository>(),
    widget.profileId,
  );

  bool _busy = false;

  /// Defaults to Shareable, and resets to it every time this screen opens.
  ///
  /// The two mistakes are not symmetric. Sending a Shareable copy to one
  /// trusted family means they ask for a phone number — recoverable. Sending a
  /// Full copy to a WhatsApp group puts a young woman's number and address
  /// into circulation that nobody can recall. So the safe mode is the default,
  /// and choosing Full is a deliberate act each time (docs/decisions.md D11).
  ExportMode _mode = ExportMode.shareable;

  bool _whatsAppAvailable = false;

  Uint8List? _photo;

  /// Whether the photo goes into *this* export (9.3).
  ///
  /// Off in Shareable and on in Full, and — critically — reset every time the
  /// mode changes rather than remembered. The failure that matters is a user
  /// who ticks "include" for one trusted family, switches to the wide-sharing
  /// copy, and sends a young woman's photograph to a WhatsApp group. Making
  /// the switch back to Shareable clear the choice means that mistake needs a
  /// second deliberate tap, in the same place the warning is.
  bool _includePhoto = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
    unawaited(_checkWhatsApp());
    unawaited(_loadPhoto());
    WidgetsBinding.instance.addPostFrameCallback((_) => _explainOnce());
  }

  Future<void> _loadPhoto() async {
    final profile = await context.read<ProfileRepository>().load(
      widget.profileId,
    );
    final bytes = await const PhotoStore().read(profile?.photoPath);
    if (mounted) setState(() => _photo = bytes);
  }

  void _setMode(ExportMode mode) => setState(() {
    _mode = mode;
    _includePhoto = mode == ExportMode.full && _photo != null;
  });

  Future<void> _checkWhatsApp() async {
    final available = await const PlatformBridge().isWhatsAppAvailable();
    if (mounted) setState(() => _whatsAppAvailable = available);
  }

  Future<void> _explainOnce() async {
    final preferences = context.read<AppPreferences>();
    if (preferences.exportModesExplained || !mounted) return;
    await showExportModeExplainer(context);
    await preferences.markExportModesExplained();
  }

  @override
  void dispose() {
    unawaited(_controller.flush());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<ExportResult> Function() job, {
    _ShareTarget share = _ShareTarget.none,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);

    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await job();
      switch (share) {
        case _ShareTarget.none:
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.exportSaved(result.files.first.path))),
          );
        case _ShareTarget.sheet:
          await _service.share(result);
        case _ShareTarget.whatsApp:
          await _service.shareToWhatsApp(result, mimeType: 'image/jpeg');
      }
    } on Object catch (error, stack) {
      debugPrint('Export failed: $error\n$stack');
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final labels = context.watch<BundledLabels>();

    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ProfileEditorController>(
        builder: (context, controller, _) {
          final profile = controller.profile;
          if (profile == null) {
            return Scaffold(
              appBar: AppBar(title: Text(l10n.exportTitle)),
              body: const Center(child: CircularProgressIndicator()),
            );
          }

          final template = Templates.byId(profile.templateId);
          final page = PageSpec.byId(profile.pageSizeId);
          final builder = DocumentBuilder(
            labels: labels,
            stringsFor: labels.stringsFor,
          );

          // Built in the selected mode, so the preview *is* the document —
          // 9.4 requires the user to see precisely what the recipient will.
          final document = builder.build(
            profile,
            mode: _mode,
            watermark: 'Made with MeriBiodata',
            // The single point at which a photo can enter a document. If this
            // is null the renderers have nothing to draw, so "excluded" is
            // structural rather than a flag someone has to remember to check.
            photo: _includePhoto ? _photo : null,
          );

          // How much Shareable would remove, computed by diffing the two
          // builds rather than by re-deriving the masking rules here.
          final fullFieldCount = builder.build(profile).fieldCount;
          final maskedCount = fullFieldCount - document.fieldCount;

          final fileName = ExportService.fileNameFor(document);

          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.exportTitle),
              actions: [
                IconButton(
                  tooltip: l10n.templatePickerTitle,
                  icon: const Icon(Icons.palette_outlined),
                  onPressed: () async {
                    await context.push(
                      AppRoutes.templatePickerFor(profile.id),
                    );
                    await controller.load();
                  },
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: DocumentPreview(
                    document: document,
                    template: template,
                    page: page,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                ExportModeSelector(
                  mode: _mode,
                  maskedFieldCount: maskedCount,
                  onChanged: _setMode,
                ),

                if (_photo != null) ...[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.portrait_outlined),
                    title: Text(l10n.photoInclude),
                    value: _includePhoto,
                    onChanged: (value) => setState(() => _includePhoto = value),
                  ),
                  if (_includePhoto && _mode == ExportMode.shareable)
                    _Notice(l10n.photoIncludeShareableWarning),
                ],
                const SizedBox(height: AppSpacing.xl),

                if (!labels.isReviewed(document.language.code))
                  _Notice(l10n.exportDraftLanguageWarning),

                _Setting(label: l10n.exportDocumentLanguage),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final language in AppLanguages.documentLanguages.where(
                      (l) => l.priority != LanguagePriority.p2,
                    ))
                      ChoiceChip(
                        label: Text(language.nativeName),
                        selected: language.code == profile.documentLanguageCode,
                        onSelected: (_) =>
                            controller.setDocumentLanguage(language.code),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                _Setting(label: l10n.exportPageSize),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final spec in PageSpec.all)
                      ChoiceChip(
                        label: Text(switch (spec.id) {
                          'a4' => l10n.exportPageA4,
                          'letter' => l10n.exportPageLetter,
                          _ => l10n.exportPageCard,
                        }),
                        selected: spec.id == page.id,
                        onSelected: (_) => controller.setPageSize(spec.id),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Three co-equal actions (§7.6). PDF is not privileged over
                // image: in Pakistan a biodata circulates on WhatsApp far more
                // often than as an attachment.
                if (_busy)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  FilledButton.icon(
                    onPressed: () => _run(
                      () => _service.exportPdf(
                        context: context,
                        document: document,
                        template: template,
                        page: page,
                        fileName: fileName,
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(l10n.exportPdf),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: () => _run(
                      () => _service.exportImages(
                        context: context,
                        document: document,
                        template: template,
                        page: page,
                        fileName: fileName,
                      ),
                    ),
                    icon: const Icon(Icons.image_outlined),
                    label: Text(l10n.exportImage),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Co-equal with the other two (9.1): a biodata reaches far
                  // more people through WhatsApp than as an emailed PDF.
                  FilledButton.icon(
                    onPressed: () => _run(
                      () => _service.exportImages(
                        context: context,
                        document: document,
                        template: template,
                        page: page,
                        fileName: fileName,
                      ),
                      share: _whatsAppAvailable
                          ? _ShareTarget.whatsApp
                          : _ShareTarget.sheet,
                    ),
                    icon: const Icon(Icons.chat_outlined),
                    label: Text(
                      _whatsAppAvailable
                          ? l10n.exportWhatsApp
                          : l10n.exportShare,
                    ),
                  ),
                  if (_whatsAppAvailable) ...[
                    const SizedBox(height: AppSpacing.sm),
                    // Most users do not know WhatsApp preserves a document but
                    // recompresses a photo. One line, where it is relevant.
                    _Notice(l10n.exportWhatsAppDocumentHint),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Where an export goes once it exists.
enum _ShareTarget { none, sheet, whatsApp }

class _Setting extends StatelessWidget {
  const _Setting({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: AppSpacing.lg),
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.lightGreen,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}
