import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/domain/biodata/field_descriptor.dart';
import 'package:meribiodata/features/editor/widgets/field_input.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

/// What the per-field overflow menu can do (§7.3).
enum FieldAction {
  rename,
  resetLabel,
  toggleRequired,
  toggleVisible,
  toggleSensitive,
  delete,
}

/// One labelled field in the form, with its overflow menu and status chips.
class FieldCard extends StatelessWidget {
  const FieldCard({
    required this.field,
    required this.label,
    required this.value,
    required this.isLabelBorrowed,
    required this.documentLanguage,
    required this.onValueChanged,
    required this.onAction,
    super.key,
  });

  final FieldDescriptor field;
  final String label;
  final Object? value;

  /// The label came from another language's override (§6.1 / D7).
  final bool isLabelBorrowed;

  /// Drives the Roman-typing offer on text fields (9.2).
  final LanguageDescriptor documentLanguage;

  final ValueChanged<Object?> onValueChanged;
  final ValueChanged<FieldAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      label,
                      style: text.titleMedium,
                      // A user can type a 60-character label; the layout has
                      // to survive it rather than overflow.
                      softWrap: true,
                    ),
                    if (field.isRequired)
                      Text(
                        '*',
                        style: text.titleMedium?.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    // The lock is the at-a-glance signal 9.4 asks for.
                    if (field.isSensitive)
                      _Chip(
                        icon: Icons.lock_outline,
                        label: l10n.fieldSensitive,
                      ),
                    if (!field.isVisible)
                      _Chip(
                        icon: Icons.visibility_off_outlined,
                        label: l10n.fieldHidden,
                      ),
                    if (isLabelBorrowed)
                      _Chip(
                        icon: Icons.translate,
                        label: l10n.fieldRenamedInOtherLanguage,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<FieldAction>(
                onSelected: onAction,
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: FieldAction.rename,
                    child: Text(l10n.menuRename),
                  ),
                  if (field.isRenamed && !field.isCustom)
                    PopupMenuItem(
                      value: FieldAction.resetLabel,
                      child: Text(l10n.menuResetLabel),
                    ),
                  PopupMenuItem(
                    value: FieldAction.toggleRequired,
                    child: Text(
                      field.isRequired
                          ? l10n.menuMarkOptional
                          : l10n.menuMarkRequired,
                    ),
                  ),
                  PopupMenuItem(
                    value: FieldAction.toggleVisible,
                    child: Text(
                      field.isVisible ? l10n.menuHide : l10n.menuShow,
                    ),
                  ),
                  PopupMenuItem(
                    value: FieldAction.toggleSensitive,
                    child: Text(
                      field.isSensitive
                          ? l10n.menuMarkNotSensitive
                          : l10n.menuMarkSensitive,
                    ),
                  ),
                  if (field.isDeletable)
                    PopupMenuItem(
                      value: FieldAction.delete,
                      child: Text(l10n.menuDeleteField),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FieldInput(
            key: ValueKey(field.id),
            field: field,
            value: value,
            onChanged: onValueChanged,
            documentLanguage: documentLanguage,
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: 2,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
