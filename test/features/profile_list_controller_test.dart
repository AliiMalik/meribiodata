import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/features/home/profile_list_controller.dart';

import '../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late ProfileRepository repository;
  late ProfileListController controller;

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    repository = ProfileRepository(store);
    controller = ProfileListController(repository);
    await controller.load();
  });

  tearDown(() => controller.dispose());

  test('starts empty', () {
    expect(controller.status, ListStatus.ready);
    expect(controller.isEmpty, isTrue);
  });

  test('creating persists immediately, so a crash cannot lose it', () async {
    final created = await controller.createProfile();

    expect(controller.isEmpty, isFalse);
    expect(await repository.load(created.id), isNotNull);
  });

  test('duplicating copies schema and answers under a new id', () async {
    final original = await controller.createProfile();
    final nameId = original.schema.fieldByBuiltInKey(BuiltInKeys.name)!.id;
    await repository.save(original.copyWith(values: {nameId: 'Ali'}));
    await controller.load();

    await controller.duplicateProfile(
      (await repository.load(original.id))!,
      'Ali (copy)',
    );

    final all = await repository.loadAll();
    expect(all.length, 2);
    final copy = all.firstWhere((p) => p.id != original.id);
    expect(copy.profileName, 'Ali (copy)');
    expect(copy.values[nameId], 'Ali');
  });

  test('deleting removes only the chosen profile', () async {
    final first = await controller.createProfile();
    final second = await controller.createProfile();

    await controller.deleteProfile(first.id);

    expect(await repository.load(first.id), isNull);
    expect(await repository.load(second.id), isNotNull);
  });

  group('search', () {
    test('matches the profile label', () async {
      final a = await controller.createProfile();
      await repository.save(a.copyWith(profileName: 'For Ayesha'));
      await controller.createProfile();
      await controller.load();

      controller.search('ayesha');

      expect(controller.visible.length, 1);
      expect(controller.visible.single.profileName, 'For Ayesha');
    });

    test('also matches the candidate name typed into the form', () async {
      final a = await controller.createProfile();
      final nameId = a.schema.fieldByBuiltInKey(BuiltInKeys.name)!.id;
      await repository.save(a.copyWith(values: {nameId: 'Bilal Ahmed'}));
      await controller.createProfile();
      await controller.load();

      controller.search('bilal');

      expect(controller.visible.length, 1);
    });

    test('an empty query shows everything', () async {
      await controller.createProfile();
      await controller.createProfile();

      controller
        ..search('nothing matches this')
        ..search('');

      expect(controller.visible.length, 2);
    });
  });

  group('display name', () {
    test('prefers the profile label', () async {
      final profile = await controller.createProfile();
      expect(
        profileDisplayName(
          profile.copyWith(profileName: 'For my son'),
          'Untitled',
        ),
        'For my son',
      );
    });

    test('falls back to the candidate name, then to the placeholder', () async {
      final profile = await controller.createProfile();
      final nameId = profile.schema.fieldByBuiltInKey(BuiltInKeys.name)!.id;

      expect(
        profileDisplayName(profile.copyWith(values: {nameId: 'Ali'}), 'X'),
        'Ali',
      );
      expect(profileDisplayName(profile, 'X'), 'X');
    });
  });
}
