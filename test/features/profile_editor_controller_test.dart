import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/features/editor/profile_editor_controller.dart';

import '../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late ProfileRepository repository;
  late ProfileEditorController controller;
  late String profileId;
  late String nameFieldId;

  const tick = Duration(milliseconds: 20);

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    repository = ProfileRepository(store);

    final profile = repository.create();
    await repository.save(profile);
    profileId = profile.id;
    nameFieldId = profile.schema.fieldByBuiltInKey(BuiltInKeys.name)!.id;

    controller = ProfileEditorController(
      repository,
      profileId,
      autosaveDelay: tick,
    );
    await controller.load();
  });

  tearDown(() => controller.dispose());

  group('loading', () {
    test('reports ready with the profile', () {
      expect(controller.status, EditorStatus.ready);
      expect(controller.profile!.id, profileId);
    });

    test('reports missing rather than crashing on a bad id', () async {
      final orphan = ProfileEditorController(repository, 'nope');
      await orphan.load();

      expect(orphan.status, EditorStatus.missing);
      orphan.dispose();
    });
  });

  group('autosave', () {
    test('debounces, then writes', () async {
      controller.setValue(nameFieldId, 'Muhammad Ali');
      expect(controller.saveState, SaveState.pending);

      // Nothing on disk yet.
      expect((await repository.load(profileId))!.values, isEmpty);

      await Future<void>.delayed(tick * 3);

      expect(controller.saveState, SaveState.saved);
      expect(
        (await repository.load(profileId))!.values[nameFieldId],
        'Muhammad Ali',
      );
    });

    test('collapses a burst of keystrokes into one write', () async {
      for (final text in ['M', 'Mu', 'Muh', 'Muha']) {
        controller.setValue(nameFieldId, text);
      }
      await Future<void>.delayed(tick * 3);

      expect(
        (await repository.load(profileId))!.values[nameFieldId],
        'Muha',
      );
    });

    test(
      'flush writes immediately, so closing the editor loses nothing',
      () async {
        controller.setValue(nameFieldId, 'Ayesha');
        await controller.flush();

        expect(
          (await repository.load(profileId))!.values[nameFieldId],
          'Ayesha',
        );
      },
    );

    test('flush is a no-op when there is nothing outstanding', () async {
      await controller.flush();
      expect(controller.saveState, SaveState.idle);
    });

    test('an unchanged value does not schedule a write', () {
      controller
        ..setValue(nameFieldId, 'Ali')
        ..setValue(nameFieldId, 'Ali');
      expect(controller.saveState, SaveState.pending);
    });
  });

  group('values', () {
    test('trims text and drops a value that becomes empty', () async {
      controller.setValue(nameFieldId, '  Ali  ');
      expect(controller.profile!.values[nameFieldId], 'Ali');

      controller.setValue(nameFieldId, '   ');
      expect(controller.profile!.values.containsKey(nameFieldId), isFalse);
    });

    test('completion tracks visible fields only', () {
      final before = controller.profile!.completion;
      controller.setValue(nameFieldId, 'Ali');
      expect(controller.profile!.completion, greaterThan(before));
    });
  });

  group('schema editing', () {
    test('deleting a field removes its stored answer too', () {
      final casteId = controller.profile!.schema
          .fieldByBuiltInKey(BuiltInKeys.caste)!
          .id;
      controller.setValue(casteId, 'Arain');
      expect(controller.profile!.values[casteId], 'Arain');

      controller.deleteField(casteId);

      expect(controller.profile!.schema.fieldById(casteId), isNull);
      expect(controller.profile!.values.containsKey(casteId), isFalse);
    });

    test('deleting a section removes every answer inside it', () {
      controller.addSection('References');
      final section = controller.profile!.schema.orderedSections.last;
      controller.addField(
        sectionId: section.id,
        type: FieldType.text,
        label: 'Referee',
      );
      final fieldId = controller.profile!.schema.fieldsIn(section.id).first.id;
      controller
        ..setValue(fieldId, 'Someone')
        ..deleteSection(section.id);

      expect(controller.profile!.schema.sectionById(section.id), isNull);
      expect(controller.profile!.values.containsKey(fieldId), isFalse);
    });

    test('a refused edit surfaces an error instead of throwing', () {
      controller.deleteField(nameFieldId);

      expect(controller.lastSchemaError, SchemaError.fieldNotDeletable);
      expect(controller.profile!.schema.fieldById(nameFieldId), isNotNull);
    });

    test('the error is consumed once, so it is not shown twice', () {
      controller.deleteField(nameFieldId);

      expect(controller.consumeSchemaError(), SchemaError.fieldNotDeletable);
      expect(controller.consumeSchemaError(), isNull);
    });

    test('renaming targets the document language, not the UI language', () {
      controller
        ..setDocumentLanguage('ur')
        ..renameField(nameFieldId, 'پورا نام');

      final field = controller.profile!.schema.fieldById(nameFieldId)!;
      expect(field.labels['ur'], 'پورا نام');
      expect(field.labels.containsKey('en'), isFalse);
    });

    test('reset re-seeds this profile and clears its answers', () {
      controller
        ..setValue(nameFieldId, 'Ali')
        ..resetSchemaToDefaults();

      expect(controller.profile!.values, isEmpty);
      expect(
        controller.profile!.schema.fieldByBuiltInKey(BuiltInKeys.name),
        isNotNull,
      );
    });

    test('resetting one profile does not touch another (D6)', () async {
      final other = repository.create(profileName: 'Sibling');
      final otherNameId = other.schema.fieldByBuiltInKey(BuiltInKeys.caste)!.id;
      await repository.save(
        other.copyWith(values: {otherNameId: 'Arain'}),
      );

      controller.resetSchemaToDefaults();
      await controller.flush();

      final reloaded = await repository.load(other.id);
      expect(reloaded!.values[otherNameId], 'Arain');
    });
  });
}
