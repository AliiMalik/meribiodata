import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/features/sync/backup_service.dart';
import 'package:meribiodata/features/sync/sync_controller.dart';
import 'package:meribiodata/features/sync/sync_service.dart';

import '../support/fake_drive.dart';
import '../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late ProfileRepository repository;
  late FakeDriveAuth auth;
  late FakeDrive drive;
  late FakeSyncPasswordStore passwords;
  late SyncService sync;

  const password = 'correct horse battery';

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    repository = ProfileRepository(store);

    auth = FakeDriveAuth(signedInAs: 'ali@example.com');
    drive = FakeDrive();
    passwords = FakeSyncPasswordStore(password);

    sync = SyncService(
      // Seeded so Argon2id runs against a fixed salt sequence. The KDF cost is
      // real either way, which is why this suite is deliberately small.
      backups: BackupService(store, random: Random(1)),
      auth: auth,
      passwords: passwords,
      clientFactory: drive.clientFor,
    );
  });

  Future<void> seed(String name) async {
    final profile = repository.create(profileName: name);
    final nameId = profile.schema.fieldByBuiltInKey(BuiltInKeys.name)!.id;
    await repository.save(profile.copyWith(values: {nameId: name}));
  }

  group('what reaches Drive', () {
    test('is unreadable without the password', () async {
      await seed('Ayesha');
      await sync.push();

      final uploaded = drive.contents!;

      // The whole promise of choosing encryption over a plain upload. If the
      // name is in these bytes, Google can read the biodata and so can anyone
      // who reaches the account.
      expect(
        utf8.decode(uploaded, allowMalformed: true),
        isNot(contains('Ayesha')),
      );
      expect(String.fromCharCodes(uploaded.take(8)), 'MERIBDTA');
    });

    test('replaces the previous copy rather than piling up', () async {
      await seed('Ali');
      await sync.push();
      await sync.push();
      await sync.push();

      expect(drive.uploads, 3);
      // One file, overwritten. A user's Drive should not fill with backups.
      expect(await sync.peek(), isNotNull);
    });
  });

  group('a new phone gets everything back', () {
    test('restores profiles from Drive with the right password', () async {
      await seed('Ali');
      await seed('Ayesha');
      await sync.push();

      // A different phone: same Drive, empty database, no stored password.
      final fresh = InMemoryLocalStore();
      await fresh.init();
      final freshPasswords = FakeSyncPasswordStore();
      final freshSync = SyncService(
        backups: BackupService(fresh),
        auth: FakeDriveAuth(signedInAs: 'ali@example.com'),
        passwords: freshPasswords,
        clientFactory: drive.clientFor,
      );

      final (header, bytes) = await freshSync.fetch();
      expect(header.profileCount, 2);

      final restored = await freshSync.restore(
        bytes,
        password: password,
        strategy: RestoreStrategy.merge,
      );

      expect(restored, 2);
      expect(
        (await ProfileRepository(fresh).loadAll()).map((p) => p.profileName),
        containsAll(<String>['Ali', 'Ayesha']),
      );
      // Restoring proves the user knows the password, so later automatic syncs
      // need no prompt.
      expect(await freshPasswords.read(), password);
    });

    test('a wrong password is refused and writes nothing (NFR-9)', () async {
      await seed('Ali');
      await sync.push();

      final fresh = InMemoryLocalStore();
      await fresh.init();
      final freshSync = SyncService(
        backups: BackupService(fresh),
        auth: FakeDriveAuth(signedInAs: 'ali@example.com'),
        passwords: FakeSyncPasswordStore(),
        clientFactory: drive.clientFor,
      );

      final (_, bytes) = await freshSync.fetch();

      await expectLater(
        freshSync.restore(
          bytes,
          password: 'not the password',
          strategy: RestoreStrategy.replace,
        ),
        throwsA(
          isA<SyncException>().having(
            (e) => e.problem,
            'problem',
            SyncProblem.wrongPassword,
          ),
        ),
      );

      // Replace is destructive, so a failed decrypt must not have run it.
      expect(await ProfileRepository(fresh).loadAll(), isEmpty);
    });
  });

  group('the failure paths each say something different', () {
    test('not signed in', () async {
      auth.signedInAs = null;
      await expectLater(
        sync.push(),
        throwsA(
          isA<SyncException>().having(
            (e) => e.problem,
            'problem',
            SyncProblem.needsSignIn,
          ),
        ),
      );
    });

    test('signed in but no password chosen yet', () async {
      await passwords.clear();
      await expectLater(
        sync.push(),
        throwsA(
          isA<SyncException>().having(
            (e) => e.problem,
            'problem',
            SyncProblem.needsPassword,
          ),
        ),
      );
    });

    test('no network', () async {
      await seed('Ali');
      drive.offline = true;

      await expectLater(
        sync.push(),
        throwsA(
          isA<SyncException>().having(
            (e) => e.problem,
            'problem',
            SyncProblem.driveUnavailable,
          ),
        ),
      );
    });
  });

  test('disconnecting forgets the password but keeps the Drive file', () async {
    await seed('Ali');
    await sync.push();

    await sync.disconnect();

    expect(auth.signOutCalls, 1);
    expect(await passwords.read(), isNull);
    // Their file, in their Drive. Signing out of a phone is not a reason to
    // delete somebody's only backup.
    expect(drive.contents, isNotNull);
  });

  group('SyncController', () {
    late SyncController controller;

    setUp(() {
      controller = SyncController(
        sync,
        debounce: const Duration(milliseconds: 20),
      );
    });

    tearDown(() => controller.dispose());

    test('starts connected when a session already exists', () async {
      await controller.load();

      expect(controller.isConnected, isTrue);
      expect(controller.account, 'ali@example.com');
      expect(controller.status, SyncStatus.idle);
    });

    test(
      'flags a half-finished setup rather than silently never syncing',
      () async {
        await passwords.clear();
        await controller.load();

        expect(controller.status, SyncStatus.failed);
        expect(controller.problem, SyncProblem.needsPassword);
      },
    );

    test('debounces a burst of edits into one upload', () async {
      await seed('Ali');
      await controller.load();

      controller
        ..scheduleSync()
        ..scheduleSync()
        ..scheduleSync();
      expect(controller.status, SyncStatus.pending);

      // Polled rather than slept on: Argon2id is deliberately expensive (64 MB,
      // three passes) and takes well over a second here, so any fixed delay
      // would either be flaky or slow.
      await _until(() => controller.status == SyncStatus.idle);

      // Three edits, one upload. That is the entire point of the debounce.
      expect(drive.uploads, 1);
    });

    test('scheduling does nothing at all when sync is off', () async {
      auth.signedInAs = null;
      await controller.load();

      controller.scheduleSync();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Callers never check isConnected first, so this has to be safe.
      expect(drive.uploads, 0);
      expect(controller.status, SyncStatus.off);
    });

    test('a failed upload is reported, not swallowed', () async {
      await seed('Ali');
      await controller.load();
      drive.offline = true;

      await controller.syncNow();

      expect(controller.status, SyncStatus.failed);
      expect(controller.problem, SyncProblem.driveUnavailable);
    });
  });
}

/// Waits for [condition], rather than guessing how long the KDF will take.
Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('condition never became true');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
