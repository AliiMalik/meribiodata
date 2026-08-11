import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/core/widgets/text_prompt_dialog.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/label_resolver.dart';
import 'package:meribiodata/features/ads/banner_slot.dart';
import 'package:meribiodata/features/editor/profile_editor_controller.dart';
import 'package:meribiodata/features/editor/widgets/field_card.dart';
import 'package:meribiodata/features/photo/photo_card.dart';
import 'package:meribiodata/features/sync/sync_controller.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';

/// The Form Editor (§7.3).
///
/// Sectioned, schema-driven, and autosaving on every change — a half-filled
/// form is never lost, because the person filling it in is often doing so in
/// one sitting on a borrowed phone.
class EditorScreen extends StatefulWidget {
  const EditorScreen({required this.profileId, super.key});

  final String profileId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
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
    // Best effort: catch anything the debounce timer had not written yet.
    unawaited(_controller.flush());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ProfileEditorController>(
        builder: (context, controller, _) => switch (controller.status) {
          EditorStatus.loading => const _Busy(),
          EditorStatus.missing => _Problem(AppL10n.of(context).editorNotFound),
          EditorStatus.failed => _Problem(
            AppL10n.of(context).errorStorageBody,
          ),
          EditorStatus.ready => _EditorBody(controller: controller),
        },
      ),
    );
  }
}

class _EditorBody extends StatelessWidget {
  const _EditorBody({required this.controller});

  final ProfileEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final profile = controller.profile!;
    final labels = context.watch<BundledLabels>();
    final resolver = LabelResolver(labels);
    final language = profile.documentLanguageCode;

    return PopScope(
      // Flush the autosave, then hand the change to sync. Leaving the editor is
      // the natural moment: the user has finished a thought, and a phone lost
      // after this point loses nothing. scheduleSync is a no-op when Drive is
      // not connected, so there is nothing to check first.
      onPopInvokedWithResult: (didPop, _) {
        unawaited(controller.flush());
        context.read<SyncController>().scheduleSync();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(profile.profileName ?? l10n.editorTitle),
          actions: [
            _SaveIndicator(state: controller.saveState),
            IconButton(
              tooltip: l10n.schemaEditorTitle,
              icon: const Icon(Icons.tune),
              onPressed: () =>
                  context.push(AppRoutes.schemaEditorFor(profile.id)),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: profile.completion,
              minHeight: 4,
              backgroundColor: context.colors.outlineVariant,
            ),
          ),
        ),
        // Two stacked bars. The next step sits above the ad, never beside it:
        // the way forward through the app must not be something a user has to
        // distinguish from an advertisement (D19).
        //
        // Reserved space below the form, never over it (§8). The form scrolls
        // above both rather than under them, so no field is ever covered.
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NextStepBar(
              onNext: () async {
                // Flushed first: the picker renders the saved profile, so an
                // unsaved keystroke would be missing from every thumbnail.
                await controller.flush();
                if (context.mounted) {
                  await context.push(AppRoutes.templatePickerFor(profile.id));
                }
                await controller.load();
              },
            ),
            const BannerSlot(screenId: 'editor'),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              l10n.editorProgress((profile.completion * 100).round()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              initialValue: profile.profileName,
              decoration: InputDecoration(
                labelText: l10n.editorProfileName,
                helperText: l10n.editorProfileNameHint,
              ),
              onChanged: controller.setProfileName,
            ),
            const SizedBox(height: AppSpacing.xl),
            // Above the fields, because a photo is not a schema field and the
            // decision to have one at all deserves its own moment (9.3).
            PhotoCard(
              photoPath: profile.photoPath,
              onSeparatePage: profile.photoOnSeparatePage,
              onPhotoChanged: (path) => unawaited(controller.setPhoto(path)),
              onSeparatePageChanged: (value) =>
                  controller.setPhotoOnSeparatePage(onSeparatePage: value),
            ),
            for (final section in profile.schema.orderedSections) ...[
              _SectionHeading(
                title: resolver.sectionTitle(section, language),
                isVisible: section.isVisible,
              ),
              for (final field in profile.schema.fieldsIn(section.id))
                FieldCard(
                  key: ValueKey(field.id),
                  field: field,
                  label: resolver.fieldLabel(field, language),
                  value: profile.valueOf(field.id),
                  isLabelBorrowed: resolver.isFieldLabelBorrowed(
                    field,
                    language,
                  ),
                  documentLanguage: AppLanguages.byCode(language),
                  onValueChanged: (value) =>
                      controller.setValue(field.id, value),
                  onAction: (action) =>
                      _handle(context, controller, field.id, action),
                ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    ProfileEditorController controller,
    String fieldId,
    FieldAction action,
  ) async {
    final l10n = AppL10n.of(context);
    final field = controller.profile!.schema.fieldById(fieldId)!;

    switch (action) {
      case FieldAction.rename:
        final label = await promptForText(
          context,
          title: l10n.menuRename,
          initialValue: field.labels[controller.documentLanguageCode] ?? '',
          maxLength: SchemaLimits.maxLabelLength,
        );
        if (label != null) controller.renameField(fieldId, label);
      case FieldAction.resetLabel:
        controller.clearRename(fieldId);
      case FieldAction.toggleRequired:
        controller.setFieldRequired(fieldId, isRequired: !field.isRequired);
      case FieldAction.toggleVisible:
        controller.setFieldVisible(fieldId, isVisible: !field.isVisible);
      case FieldAction.toggleSensitive:
        controller.setFieldSensitive(fieldId, isSensitive: !field.isSensitive);
      case FieldAction.delete:
        controller.deleteField(fieldId);
    }

    if (context.mounted) _showSchemaError(context, controller);
  }
}

void _showSchemaError(
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

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.isVisible});

  final String title;
  final bool isVisible;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (!isVisible)
          Icon(
            Icons.visibility_off_outlined,
            size: 18,
            color: context.colors.onSurfaceVariant,
          ),
      ],
    ),
  );
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.state});

  final SaveState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final (label, icon) = switch (state) {
      SaveState.idle => (null, null),
      SaveState.pending || SaveState.saving => (
        l10n.editorSaving,
        Icons.sync,
      ),
      SaveState.saved => (l10n.editorSaved, Icons.check),
      SaveState.failed => (l10n.editorSaveFailed, Icons.error_outline),
    };
    if (label == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).appBarTheme.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Problem extends StatelessWidget {
  const _Problem(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}

/// The way out of the form (D19).
///
/// Replaces an eye icon in the app bar, which was the only route to the export
/// screen and which nobody found — a filled bar at the bottom of the page is
/// where a person who has just finished typing actually looks.
class _NextStepBar extends StatelessWidget {
  const _NextStepBar({required this.onNext});

  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => unawaited(onNext()),
              icon: const Icon(Icons.arrow_forward),
              label: Text(l10n.editorNextTemplate),
            ),
          ),
        ),
      ),
    );
  }
}
