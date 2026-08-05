import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/render/document_builder.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/domain/render/templates.dart';
import 'package:meribiodata/features/editor/profile_editor_controller.dart';
import 'package:meribiodata/features/export/export_service.dart';
import 'package:meribiodata/features/export/widgets/document_preview.dart';
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

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
  }

  @override
  void dispose() {
    unawaited(_controller.flush());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<ExportResult> Function() job, {
    bool thenShare = false,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);

    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await job();
      if (thenShare) {
        await _service.share(result);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.exportSaved(result.files.first.path))),
        );
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
          final document = DocumentBuilder(
            labels: labels,
            stringsFor: labels.stringsFor,
          ).build(profile, watermark: 'Made with MeriBiodata');

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
                  OutlinedButton.icon(
                    onPressed: () => _run(
                      () => _service.exportImages(
                        context: context,
                        document: document,
                        template: template,
                        page: page,
                        fileName: fileName,
                      ),
                      thenShare: true,
                    ),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.exportShare),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

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
