import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/core/widgets/text_prompt_dialog.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/label_resolver.dart';
import 'package:meribiodata/domain/biodata/section_descriptor.dart';
import 'package:meribiodata/features/editor/profile_editor_controller.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// The Schema Editor (§7.4): reorder sections and fields, add and remove them,
/// and reset this biodata back to the standard set.
class SchemaEditorScreen extends StatefulWidget {
  const SchemaEditorScreen({required this.profileId, super.key});

  final String profileId;

  @override
  State<SchemaEditorScreen> createState() => _SchemaEditorScreenState();
}

class _SchemaEditorScreenState extends State<SchemaEditorScreen> {
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

          final resolver = LabelResolver(context.watch<BundledLabels>());
          final language = profile.documentLanguageCode;
          final schema = profile.schema;

          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.schemaEditorTitle),
              actions: [
                IconButton(
                  tooltip: l10n.schemaReset,
                  icon: const Icon(Icons.restart_alt),
                  onPressed: () => _reset(context, controller),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _addSection(context, controller),
              icon: const Icon(Icons.add),
              label: Text(l10n.schemaAddSection),
            ),
            body: ReorderableListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xxl * 2,
              ),
              // onReorderItem, not the deprecated onReorder: it hands back a
              // newIndex already adjusted for the removed item, which is the
              // off-by-one every reorderable list gets wrong.
              onReorderItem: (oldIndex, newIndex) => controller.moveSection(
                schema.orderedSections[oldIndex].id,
                newIndex,
              ),
              children: [
                for (final section in schema.orderedSections)
                  _SectionPanel(
                    key: ValueKey(section.id),
                    section: section,
                    title: resolver.sectionTitle(section, language),
                    schema: schema,
                    controller: controller,
                    resolver: resolver,
                    language: language,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addSection(
    BuildContext context,
    ProfileEditorController controller,
  ) async {
    final l10n = AppL10n.of(context);
    final title = await promptForText(
      context,
      title: l10n.schemaAddSection,
      maxLength: SchemaLimits.maxLabelLength,
    );
    if (title != null) controller.addSection(title);
    if (context.mounted) _reportSchemaError(context, controller);
  }

  Future<void> _reset(
    BuildContext context,
    ProfileEditorController controller,
  ) async {
    final l10n = AppL10n.of(context);
    final confirmed = await confirm(
      context,
      title: l10n.schemaResetTitle,
      body: l10n.schemaResetBody,
      confirmLabel: l10n.schemaReset,
      isDestructive: true,
    );
    if (confirmed) controller.resetSchemaToDefaults();
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.section,
    required this.title,
    required this.schema,
    required this.controller,
    required this.resolver,
    required this.language,
    super.key,
  });

  final SectionDescriptor section;
  final String title;
  final BiodataSchema schema;
  final ProfileEditorController controller;
  final LabelResolver resolver;
  final String language;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final fields = schema.fieldsIn(section.id);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: section.order,
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: Icon(
                      Icons.drag_handle,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: section.isVisible ? l10n.menuHide : l10n.menuShow,
                  icon: Icon(
                    section.isVisible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => controller.setSectionVisible(
                    section.id,
                    isVisible: !section.isVisible,
                  ),
                ),
                PopupMenuButton<_SectionAction>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) => _handle(context, action),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _SectionAction.rename,
                      child: Text(l10n.menuRename),
                    ),
                    PopupMenuItem(
                      value: _SectionAction.addField,
                      child: Text(l10n.schemaAddField),
                    ),
                    if (section.isDeletable)
                      PopupMenuItem(
                        value: _SectionAction.delete,
                        child: Text(l10n.actionDelete),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(),
            for (var i = 0; i < fields.length; i++)
              ListTile(
                key: ValueKey(fields[i].id),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  fields[i].isVisible
                      ? Icons.check_box_outlined
                      : Icons.check_box_outline_blank,
                  color: context.colors.onSurfaceVariant,
                ),
                title: Text(resolver.fieldLabel(fields[i], language)),
                subtitle: fields[i].isSensitive
                    ? Text(l10n.fieldSensitive)
                    : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: i == 0
                          ? null
                          : () => controller.moveField(fields[i].id, i - 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: i == fields.length - 1
                          ? null
                          : () => controller.moveField(fields[i].id, i + 1),
                    ),
                  ],
                ),
                onTap: () => controller.setFieldVisible(
                  fields[i].id,
                  isVisible: !fields[i].isVisible,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, _SectionAction action) async {
    final l10n = AppL10n.of(context);

    switch (action) {
      case _SectionAction.rename:
        final title = await promptForText(
          context,
          title: l10n.menuRename,
          initialValue: section.titles[language] ?? '',
          maxLength: SchemaLimits.maxLabelLength,
        );
        if (title != null) controller.renameSection(section.id, title);
      case _SectionAction.addField:
        if (context.mounted) await _addField(context);
      case _SectionAction.delete:
        final confirmed = await confirm(
          context,
          title: l10n.actionDelete,
          body: l10n.schemaResetBody,
          confirmLabel: l10n.actionDelete,
          isDestructive: true,
        );
        if (confirmed) controller.deleteSection(section.id);
    }

    if (context.mounted) _reportSchemaError(context, controller);
  }

  Future<void> _addField(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final label = await promptForText(
      context,
      title: l10n.schemaAddField,
      maxLength: SchemaLimits.maxLabelLength,
    );
    if (label == null || !context.mounted) return;

    final type = await showModalBottomSheet<FieldType>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final type in FieldType.values)
              ListTile(
                title: Text(type.wire),
                onTap: () => Navigator.of(context).pop(type),
              ),
          ],
        ),
      ),
    );
    if (type == null) return;

    controller.addField(sectionId: section.id, type: type, label: label);
  }
}

enum _SectionAction { rename, addField, delete }

void _reportSchemaError(
  BuildContext context,
  ProfileEditorController controller,
) {
  final error = controller.consumeSchemaError();
  if (error == null) return;

  final l10n = AppL10n.of(context);
  final message = switch (error) {
    SchemaError.fieldLimitReached => l10n.errorFieldLimit(
      SchemaLimits.maxFields,
    ),
    SchemaError.sectionLimitReached => l10n.errorSectionLimit(
      SchemaLimits.maxSections,
    ),
    SchemaError.fieldNotDeletable => l10n.errorFieldNotDeletable,
    SchemaError.sectionNotDeletable => l10n.errorSectionNotDeletable,
    SchemaError.labelEmpty => l10n.errorLabelEmpty,
    SchemaError.labelTooLong => l10n.errorLabelTooLong,
    SchemaError.fieldNotFound ||
    SchemaError.sectionNotFound ||
    SchemaError.sectionNotEmpty => l10n.errorGenericTitle,
  };

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
