import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/biodata_profile.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/schema_editor.dart';

enum EditorStatus { loading, ready, missing, failed }

/// Whether unsaved work is outstanding. Surfaced in the app bar so the user
/// can see that autosave is real rather than having to trust it.
enum SaveState { idle, pending, saving, saved, failed }

/// Drives the Form Editor.
///
/// Thin by design: every schema change delegates to the pure functions in
/// `schema_editor.dart`, so the logic is tested without a widget tree and this
/// class only handles state, debouncing and persistence.
class ProfileEditorController extends ChangeNotifier {
  ProfileEditorController(
    this._repository,
    this._profileId, {
    this.autosaveDelay = const Duration(milliseconds: 600),
  }) : assert(_profileId != '', 'a profile id is required');

  /// Long enough not to write on every keystroke, short enough that leaving
  /// the screen or backgrounding the app almost never races it. [flush] covers
  /// the rest.
  final Duration autosaveDelay;

  final ProfileRepository _repository;
  final String _profileId;

  Timer? _debounce;
  BiodataProfile? _profile;
  EditorStatus _status = EditorStatus.loading;
  SaveState _saveState = SaveState.idle;
  SchemaError? _lastSchemaError;
  bool _disposed = false;

  BiodataProfile? get profile => _profile;
  EditorStatus get status => _status;
  SaveState get saveState => _saveState;

  /// Set when a schema edit was refused, e.g. the field cap was reached.
  /// Cleared by [consumeSchemaError] once shown.
  SchemaError? get lastSchemaError => _lastSchemaError;

  String get documentLanguageCode => _profile?.documentLanguageCode ?? 'en';

  SchemaError? consumeSchemaError() {
    final error = _lastSchemaError;
    _lastSchemaError = null;
    return error;
  }

  Future<void> load() async {
    try {
      final loaded = await _repository.load(_profileId);
      if (loaded == null) {
        _status = EditorStatus.missing;
      } else {
        _profile = loaded;
        _status = EditorStatus.ready;
      }
    } on Object {
      _status = EditorStatus.failed;
    }
    _notify();
  }

  // --- Values ----------------------------------------------------------

  void setValue(String fieldId, Object? value) {
    final current = _profile;
    if (current == null) return;

    final values = {...current.values};
    if (value == null || (value is String && value.trim().isEmpty)) {
      values.remove(fieldId);
    } else {
      values[fieldId] = value is String ? value.trim() : value;
    }
    if (mapEquals(values, current.values)) return;

    _profile = current.copyWith(values: values);
    _scheduleSave();
  }

  void setProfileName(String? name) {
    final current = _profile;
    if (current == null) return;
    final trimmed = name?.trim();
    if (trimmed == current.profileName) return;
    _profile = current.copyWith(
      profileName: (trimmed?.isEmpty ?? true) ? null : trimmed,
    );
    _scheduleSave();
  }

  void setTemplate(String templateId) {
    final current = _profile;
    if (current == null || current.templateId == templateId) return;
    _profile = current.copyWith(templateId: templateId);
    _scheduleSave();
  }

  void setPageSize(String pageId) {
    final current = _profile;
    if (current == null || current.pageSizeId == pageId) return;
    _profile = current.copyWith(pageSizeId: pageId);
    _scheduleSave();
  }

  void setDocumentLanguage(String localeCode) {
    final current = _profile;
    if (current == null || current.documentLanguageCode == localeCode) return;
    _profile = current.copyWith(documentLanguageCode: localeCode);
    _scheduleSave();
  }

  // --- Schema ----------------------------------------------------------

  /// Applies a pure schema mutation, catching the refusals so the UI can show
  /// a message instead of crashing.
  void editSchema(BiodataSchema Function(BiodataSchema) mutate) {
    final current = _profile;
    if (current == null) return;
    try {
      _profile = current.copyWith(schema: mutate(current.schema));
      _scheduleSave();
    } on SchemaException catch (e) {
      _lastSchemaError = e.error;
      _notify();
    }
  }

  void renameField(String fieldId, String label) => editSchema(
    (s) => s.renameField(
      fieldId,
      label: label,
      localeCode: documentLanguageCode,
    ),
  );

  void clearRename(String fieldId) =>
      editSchema((s) => s.clearFieldRename(fieldId, documentLanguageCode));

  void setFieldVisible(String fieldId, {required bool isVisible}) =>
      editSchema((s) => s.setFieldVisible(fieldId, isVisible: isVisible));

  void setFieldRequired(String fieldId, {required bool isRequired}) =>
      editSchema((s) => s.setFieldRequired(fieldId, isRequired: isRequired));

  void setFieldSensitive(String fieldId, {required bool isSensitive}) =>
      editSchema((s) => s.setFieldSensitive(fieldId, isSensitive: isSensitive));

  void moveField(String fieldId, int newIndex) =>
      editSchema((s) => s.moveField(fieldId, newIndex));

  void moveSection(String sectionId, int newIndex) =>
      editSchema((s) => s.moveSection(sectionId, newIndex));

  void renameSection(String sectionId, String title) => editSchema(
    (s) => s.renameSection(
      sectionId,
      title: title,
      localeCode: documentLanguageCode,
    ),
  );

  void setSectionVisible(String sectionId, {required bool isVisible}) =>
      editSchema((s) => s.setSectionVisible(sectionId, isVisible: isVisible));

  void addField({
    required String sectionId,
    required FieldType type,
    required String label,
    bool isRequired = false,
    bool isSensitive = false,
    List<String>? options,
  }) => editSchema(
    (s) => s.addField(
      sectionId: sectionId,
      type: type,
      label: label,
      localeCode: documentLanguageCode,
      newId: _repository.newId,
      isRequired: isRequired,
      isSensitive: isSensitive,
      options: options,
    ),
  );

  void addSection(String title) => editSchema(
    (s) => s.addSection(
      title: title,
      localeCode: documentLanguageCode,
      newId: _repository.newId,
    ),
  );

  /// Deleting a field drops its stored answer too — keeping an orphaned value
  /// would resurrect it if a field with the same id were ever restored.
  void deleteField(String fieldId) {
    final current = _profile;
    if (current == null) return;
    try {
      final schema = current.schema.deleteField(fieldId);
      _profile = current.copyWith(
        schema: schema,
        values: {...current.values}..remove(fieldId),
      );
      _scheduleSave();
    } on SchemaException catch (e) {
      _lastSchemaError = e.error;
      _notify();
    }
  }

  void deleteSection(String sectionId) {
    final current = _profile;
    if (current == null) return;
    try {
      final orphaned = current.schema.fieldIdsIn(sectionId);
      final schema = current.schema.deleteSection(sectionId);
      final values = {...current.values}
        ..removeWhere((key, _) => orphaned.contains(key));
      _profile = current.copyWith(schema: schema, values: values);
      _scheduleSave();
    } on SchemaException catch (e) {
      _lastSchemaError = e.error;
      _notify();
    }
  }

  /// Re-seeds this profile's schema (D6 — only this profile's).
  ///
  /// Values are dropped along with the old field ids, because the new schema's
  /// fields are new objects. This is destructive and the UI must confirm.
  void resetSchemaToDefaults() {
    final current = _profile;
    if (current == null) return;
    _profile = current.copyWith(
      schema: DefaultSchema.build(newId: _repository.newId),
      values: const {},
    );
    _scheduleSave();
  }

  // --- Saving ----------------------------------------------------------

  void _scheduleSave() {
    _saveState = SaveState.pending;
    _notify();

    _debounce?.cancel();
    _debounce = Timer(autosaveDelay, () {
      unawaited(_write());
    });
  }

  /// Writes immediately if anything is outstanding. Called when the editor is
  /// closed or the app is backgrounded — a half-filled form must never be lost.
  Future<void> flush() async {
    if (_saveState != SaveState.pending) return;
    _debounce?.cancel();
    await _write();
  }

  Future<void> _write() async {
    final current = _profile;
    if (current == null) return;

    _saveState = SaveState.saving;
    _notify();
    try {
      await _repository.save(current);
      _saveState = SaveState.saved;
    } on Object {
      // Keep the edit in memory. The next change retries, and flush() gets one
      // more attempt on the way out.
      _saveState = SaveState.failed;
    }
    _notify();
  }

  /// The final flush is deliberately started from `dispose()` and outlives the
  /// widget, so the write must complete but the notification must not fire.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
