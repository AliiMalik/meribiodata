import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';

/// The Full vs Shareable choice (9.4).
///
/// Deliberately loud. A biodata gets forwarded through groups the sender does
/// not control, and someone accidentally sending the Full copy to a group chat
/// is the exact failure this feature exists to prevent — so the selected mode
/// is stated in words, colour and a count, not just a highlighted segment.
class ExportModeSelector extends StatelessWidget {
  const ExportModeSelector({
    required this.mode,
    required this.maskedFieldCount,
    required this.onChanged,
    super.key,
  });

  final ExportMode mode;

  /// How many fields this document would hide or shorten in Shareable mode.
  final int maskedFieldCount;

  final ValueChanged<ExportMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;
    final isShareable = mode == ExportMode.shareable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.exportMode, style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<ExportMode>(
          segments: [
            ButtonSegment(
              value: ExportMode.shareable,
              icon: const Icon(Icons.groups_outlined),
              label: Text(l10n.exportModeShareable),
            ),
            ButtonSegment(
              value: ExportMode.full,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(l10n.exportModeFull),
            ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            // Shareable reads as safe; Full is the one that needs a second
            // look, so it gets the warning treatment rather than the calm one.
            color: isShareable ? AppColors.lightGreen : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isShareable ? Icons.shield_outlined : Icons.warning_amber,
                size: 18,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isShareable
                          ? l10n.exportModeShareableHint
                          : l10n.exportModeFullHint,
                      style: text.bodyMedium,
                    ),
                    if (isShareable && maskedFieldCount > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.exportModeHiddenCount(maskedFieldCount),
                        style: text.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown once, the first time the user reaches the export screen (9.4).
Future<void> showExportModeExplainer(BuildContext context) async {
  final l10n = AppL10n.of(context);

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.exportExplainTitle),
      content: SingleChildScrollView(child: Text(l10n.exportExplainBody)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.exportExplainGotIt),
        ),
      ],
    ),
  );
}
