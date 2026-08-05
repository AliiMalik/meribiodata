import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/features/backup/backup_format.dart';
import 'package:meribiodata/features/backup/backup_service.dart';

import '../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late ProfileRepository repository;
  late BackupService service;

  const password = 'correct horse battery';

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    repository = ProfileRepository(store);
    // Seeded so Argon2id runs against a fixed salt sequence; the KDF cost is
    // real either way, which is why this suite is deliberately small.
    service = BackupService(store, random: Random(1));
  });

  Future<String> seedProfile(String name) async {
    final profile = repository.create(profileName: name);
    final nameId = profile.schema.fieldByBuiltInKey(BuiltInKeys.name)!.id;
    await repository.save(
      profile.copyWith(values: {nameId: name, 'stray': 'value'}),
    );
    return profile.id;
  }

  group('round trip', () {
    test('restores every profile, its schema and its answers', () async {
      await seedProfile('Ali');
      await seedProfile('Ayesha');
      await store.put(Collections.preferences, 'app', {'uiLocale': 'ur'});

      final bytes = await service.create(password: password);

      // Wipe the device completely, as a new phone would be.
      final fresh = InMemoryLocalStore();
      await fresh.init();
      final restorer = BackupService(fresh);

      final contents = await restorer.open(bytes, password: password);
      await restorer.restore(contents, strategy: RestoreStrategy.merge);

      final restored = await ProfileRepository(fresh).loadAll();
      expect(restored.length, 2);
      expect(
        restored.map((p) => p.profileName),
        containsAll(<String>['Ali', 'Ayesha']),
      );
      // A restore must reproduce the app, not just the text (9.5).
      expect(restored.first.schema.fields, isNotEmpty);
      expect(
        await fresh.read(Collections.preferences, 'app'),
        {'uiLocale': 'ur'},
      );
    });

    test('the header previews the file without the password (9.5)', () async {
      await seedProfile('Ali');
      final bytes = await service.create(password: password);

      final header = service.inspect(bytes);

      expect(header.profileCount, 1);
      expect(header.formatVersion, BackupFormat.currentVersion);
      expect(header.appVersion, isNotEmpty);
      expect(header.createdAt.year, greaterThan(2020));
    });

    test('the payload is not readable without the password', () async {
      await seedProfile('Muhammad Ali Malik');
      final bytes = await service.create(password: password);

      // The header is plaintext by design, but nothing personal is in it.
      expect(
        utf8.decode(bytes, allowMalformed: true),
        isNot(contains('Malik')),
      );
    });
  });

  group('failure paths (9.5)', () {
    test('a wrong password is refused', () async {
      await seedProfile('Ali');
      final bytes = await service.create(password: password);

      expect(
        () => service.open(bytes, password: 'not the password'),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.wrongPasswordOrTampered,
          ),
        ),
      );
    });

    test('a tampered payload is detected, not silently accepted', () async {
      await seedProfile('Ali');
      final bytes = await service.create(password: password);

      // Flip one bit deep in the ciphertext. Authenticated encryption is what
      // turns this into an error rather than garbage data (NFR-9).
      final tampered = Uint8List.fromList(bytes);
      tampered[tampered.length - 5] ^= 0x01;

      expect(
        () => service.open(tampered, password: password),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.wrongPasswordOrTampered,
          ),
        ),
      );
    });

    test('a file that is not a backup is rejected immediately', () {
      expect(
        () => service.inspect(Uint8List.fromList(utf8.encode('hello world'))),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.notABackup,
          ),
        ),
      );
    });

    test('a truncated file is reported as corrupt', () async {
      await seedProfile('Ali');
      final bytes = await service.create(password: password);
      final truncated = bytes.sublist(0, bytes.length ~/ 2);

      expect(
        () => service.open(truncated, password: password),
        throwsA(isA<BackupException>()),
      );
    });

    test('a newer format version is refused with a clear error', () {
      // Hand-built v2 file: this is exactly what a future app would write.
      final header = BackupHeader(
        formatVersion: BackupFormat.currentVersion + 1,
        appVersion: '9.9.9',
        createdAt: DateTime.utc(2030),
        profileCount: 3,
      );
      final future = Uint8List.fromList([
        ...BackupFormat.buildPreamble(header),
        ...List.filled(64, 0),
      ]);

      expect(
        () => service.inspect(future),
        throwsA(
          isA<BackupException>().having(
            (e) => e.error,
            'error',
            BackupError.futureVersion,
          ),
        ),
      );
    });

    test('a failed open writes nothing (NFR-9)', () async {
      await seedProfile('Existing');
      final bytes = await service.create(password: password);
      final before = (await repository.loadAll()).length;

      await expectLater(
        () => service.open(bytes, password: 'wrong'),
        throwsA(isA<BackupException>()),
      );

      // Decryption and parsing both finish before anything is written, so a
      // bad file can never leave the app half-restored.
      expect((await repository.loadAll()).length, before);
    });
  });

  group('merge vs replace', () {
    test('merge keeps profiles that are not in the file', () async {
      await seedProfile('FromBackup');
      final bytes = await service.create(password: password);

      final target = InMemoryLocalStore();
      await target.init();
      final targetRepo = ProfileRepository(target);
      await targetRepo.save(targetRepo.create(profileName: 'AlreadyHere'));

      final restorer = BackupService(target);
      await restorer.restore(
        await restorer.open(bytes, password: password),
        strategy: RestoreStrategy.merge,
      );

      expect(
        (await targetRepo.loadAll()).map((p) => p.profileName),
        containsAll(<String>['AlreadyHere', 'FromBackup']),
      );
    });

    test('replace removes what was already there', () async {
      await seedProfile('FromBackup');
      final bytes = await service.create(password: password);

      final target = InMemoryLocalStore();
      await target.init();
      final targetRepo = ProfileRepository(target);
      await targetRepo.save(targetRepo.create(profileName: 'AlreadyHere'));

      final restorer = BackupService(target);
      await restorer.restore(
        await restorer.open(bytes, password: password),
        strategy: RestoreStrategy.replace,
      );

      final names = (await targetRepo.loadAll()).map((p) => p.profileName);
      expect(names, ['FromBackup']);
    });
  });

  test(
    'two backups of the same data differ, because the salt is random',
    () async {
      await seedProfile('Ali');
      final unseeded = BackupService(store);

      final first = await unseeded.create(password: password);
      final second = await unseeded.create(password: password);

      // Identical salts and nonces across files would leak far more than
      // ciphertext similarity; this pins the per-file randomness.
      expect(first, isNot(equals(second)));
    },
  );
}
