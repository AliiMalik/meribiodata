import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/render/document_builder.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/domain/render/templates.dart';
import 'package:meribiodata/features/editor/profile_editor_controller.dart';
import 'package:meribiodata/features/export/widgets/document_preview.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// §7.5 — visual thumbnails with a live preview of the user's real data.
///
/// The thumbnails are the real renderer at a small scale rather than shipped
/// images, so a template can never look different in the picker from how it
/// exports.
class TemplatePickerScreen extends StatefulWidget {
  const TemplatePickerScreen({required this.profileId, super.key});

  final String profileId;

  @override
  State<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends State<TemplatePickerScreen> {
  late final ProfileEditorController _controller = ProfileEditorController(
    context.read<ProfileRepository>(),
    widget.profileId,
  );

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
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final document = DocumentBuilder(
            labels: labels,
            stringsFor: labels.stringsFor,
            units: context.watch<AppPreferences>().documentUnits,
          ).build(profile);
          final selected = profile.templateId ?? Templates.defaultId;

          return Scaffold(
            appBar: AppBar(title: Text(l10n.templatePickerTitle)),
            body: GridView.count(
              padding: const EdgeInsets.all(AppSpacing.lg),
              crossAxisCount: 2,
              childAspectRatio: 0.62,
              mainAxisSpacing: AppSpacing.lg,
              crossAxisSpacing: AppSpacing.lg,
              children: [
                for (final template in Templates.all)
                  _TemplateCard(
                    template: template,
                    isSelected: template.id == selected,
                    preview: DocumentPreview(
                      document: document,
                      template: template,
                      page: PageSpec.a4,
                      maxWidth: 150,
                    ),
                    onTap: () => controller.setTemplate(template.id),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.preview,
    required this.onTap,
  });

  final DocumentTemplate template;
  final bool isSelected;
  final Widget preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? AppColors.lightGreen : null,
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: preview)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) ...[
                  const Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    template.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            if (template.isMonochrome)
              Text(
                l10n.templateMonochrome,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
