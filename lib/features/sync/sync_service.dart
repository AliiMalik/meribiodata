import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meribiodata/features/sync/backup_format.dart';
import 'package:meribiodata/features/sync/backup_service.dart';
import 'package:meribiodata/features/sync/drive_auth.dart';
import 'package:meribiodata/features/sync/drive_client.dart';

/// Why a sync could not happen. Each maps to a different thing to say and a
/// different thing to offer.
enum SyncProblem {
  /// Nobody is signed in, or the Drive permission was withdrawn.
  needsSignIn,

  /// Signed in, but the app has no password to encrypt with yet.
  needsPassword,

  /// Reached Drive, but it refused or the network died.
  driveUnavailable,

  /// A backup exists but this password does not open it.
  wrongPassword,

  /// The file is damaged, or was written by a newer version.
  unreadableBackup,
}

class SyncException implements Exception {
  const SyncException(this.problem, [this.cause]);

  final SyncProblem problem;
  final Object? cause;

  @override
  String toString() =>
      'SyncException: ${problem.name}'
      '${cause == null ? '' : ' ($cause)'}';
}

/// Where the sync password lives between sessions.
///
/// The platform keystore, not the app's own storage — the same reasoning as
/// the database key (NFR-6). Keeping it means automatic sync can encrypt
/// without asking every time; it is a convenience cache, and losing it costs
/// the user one re-entry rather than their data.
///
/// On a new phone there is deliberately nothing here: restoring is exactly the
/// case where the user must prove they know the password.
class SyncPasswordStore {
  const SyncPasswordStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'meribiodata.sync_password.v1';

  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String password) =>
      _storage.write(key: _key, value: password);
  Future<void> clear() => _storage.delete(key: _key);
}

/// Ties the encrypted payload to the Drive transport.
///
/// The split matters: [BackupService] turns the database into an encrypted
/// blob and back, [DriveClient] moves opaque bytes, and this class is the only
/// place that knows both exist. Neither of the other two can leak plaintext,
/// because neither ever holds it and the transport at no point sees a password.
class SyncService {
  SyncService({
    required BackupService backups,
    required DriveAuth auth,
    this.passwords = const SyncPasswordStore(),
    DriveClient Function(DriveIdentity)? clientFactory,
    // The fields are private; Dart forbids a named parameter starting with an
    // underscore, so `required this._backups` is not available here.
    // ignore: prefer_initializing_formals
  }) : _backups = backups,
       // Same reason as above.
       // ignore: prefer_initializing_formals
       _auth = auth,
       _clientFactory = clientFactory ?? DriveClient.new;

  final BackupService _backups;
  final DriveAuth _auth;

  /// Injected in tests, which cannot reach the platform keystore.
  final SyncPasswordStore passwords;
  final DriveClient Function(DriveIdentity) _clientFactory;

  /// Whoever is signed in, without prompting.
  Future<DriveIdentity?> currentAccount() => _auth.current();

  /// Prompts for an account and the Drive permission.
  Future<DriveIdentity?> signIn() => _auth.signIn();

  Future<DriveIdentity> _requireIdentity() async {
    final identity = await _auth.current();
    if (identity == null) throw const SyncException(SyncProblem.needsSignIn);
    return identity;
  }

  Future<String> _requirePassword() async {
    final password = await passwords.read();
    if (password == null || password.isEmpty) {
      throw const SyncException(SyncProblem.needsPassword);
    }
    return password;
  }

  /// Encrypts everything and writes it to Drive.
  Future<RemoteBackup> push() async {
    final identity = await _requireIdentity();
    final password = await _requirePassword();

    final bytes = await _backups.create(password: password);

    try {
      return await _clientFactory(identity).upload(bytes);
    } on SyncException {
      rethrow;
    } on Object catch (e) {
      throw SyncException(SyncProblem.driveUnavailable, e);
    }
  }

  /// What is in Drive, if anything, without downloading or decrypting it.
  Future<RemoteBackup?> peek() async {
    final identity = await _requireIdentity();
    try {
      return await _clientFactory(identity).find();
    } on Object catch (e) {
      throw SyncException(SyncProblem.driveUnavailable, e);
    }
  }

  /// Downloads the backup and reads its plaintext header, so the restore
  /// screen can say what is inside before asking for a password.
  Future<(BackupHeader header, Uint8List bytes)> fetch() async {
    final identity = await _requireIdentity();

    final Uint8List bytes;
    try {
      final client = _clientFactory(identity);
      final remote = await client.find();
      if (remote == null) {
        throw const SyncException(SyncProblem.unreadableBackup);
      }
      bytes = await client.download(remote.fileId);
    } on SyncException {
      rethrow;
    } on Object catch (e) {
      throw SyncException(SyncProblem.driveUnavailable, e);
    }

    try {
      return (_backups.inspect(bytes), bytes);
    } on BackupException catch (e) {
      throw SyncException(SyncProblem.unreadableBackup, e);
    }
  }

  /// Decrypts [bytes] and applies them, then remembers the password so later
  /// automatic syncs need no prompt.
  ///
  /// Everything is decrypted and parsed before a single write happens, so a
  /// wrong password or a damaged file leaves what is on the phone untouched
  /// (NFR-9).
  Future<int> restore(
    Uint8List bytes, {
    required String password,
    required RestoreStrategy strategy,
  }) async {
    final BackupContents contents;
    try {
      contents = await _backups.open(bytes, password: password);
    } on BackupException catch (e) {
      throw SyncException(
        e.error == BackupError.wrongPasswordOrTampered
            ? SyncProblem.wrongPassword
            : SyncProblem.unreadableBackup,
        e,
      );
    }

    await _backups.restore(contents, strategy: strategy);
    await passwords.write(password);
    return contents.profiles.length;
  }

  /// Sets the password for a phone that is starting fresh.
  Future<void> setPassword(String password) => passwords.write(password);

  Future<bool> hasPassword() async =>
      (await passwords.read())?.isNotEmpty ?? false;

  /// Signs out and forgets the password. The Drive file is deliberately left
  /// alone: it is the user's file, in the user's Drive, and deleting their
  /// backup because they signed out of a phone would be indefensible.
  Future<void> disconnect() async {
    await _auth.signOut();
    await passwords.clear();
  }
}
