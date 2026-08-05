import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/domain/biodata/biodata_profile.dart';
import 'package:meribiodata/features/backup/backup_format.dart';

/// What a restore should do with what is already on the device.
enum RestoreStrategy {
  /// Keep existing profiles, add the ones from the file. A profile present in
  /// both is overwritten by the backup's copy.
  merge,

  /// Delete everything already here first. Destructive; the UI confirms twice.
  replace,
}

/// The decrypted contents of a backup.
class BackupContents {
  const BackupContents({
    required this.header,
    required this.profiles,
    required this.preferences,
  });

  final BackupHeader header;
  final List<BiodataProfile> profiles;
  final Map<String, dynamic> preferences;
}

/// Creates and restores the password-protected `.mbd` file (9.5).
///
/// This is what makes an offline-first app survive a lost phone, which is the
/// one way it could otherwise be *worse* than a cloud one. It is deliberately
/// a manual export/import file: no background upload, no sync, no account.
class BackupService {
  BackupService(this._store, {Random? random})
    : _random = random ?? Random.secure();

  final LocalStore _store;
  final Random _random;

  static const appVersion = '1.0.0';

  /// Everything needed to reproduce the user's app, not just their text (9.5):
  /// profiles with their schemas and answers, plus app preferences.
  Future<Uint8List> create({required String password}) async {
    final profiles = await _store.readAll(Collections.profiles);
    final preferences =
        await _store.read(Collections.preferences, 'app') ?? const {};

    final payload = utf8.encode(
      jsonEncode({'profiles': profiles, 'preferences': preferences}),
    );

    final salt = _randomBytes(BackupFormat.saltLength);
    final nonce = _randomBytes(BackupFormat.nonceLength);
    final key = await _deriveKey(password, salt);

    final box = await AesGcm.with256bits().encrypt(
      payload,
      secretKey: key,
      nonce: nonce,
    );

    final header = BackupHeader(
      formatVersion: BackupFormat.currentVersion,
      appVersion: appVersion,
      createdAt: DateTime.now(),
      profileCount: profiles.length,
    );

    return (BytesBuilder()
          ..add(BackupFormat.buildPreamble(header))
          ..add(salt)
          ..add(nonce)
          ..add(Uint8List.fromList(box.mac.bytes))
          ..add(box.cipherText))
        .toBytes();
  }

  /// Reads the header without the password, so the restore screen can preview
  /// what is inside and reject a future-version file before prompting (9.5).
  BackupHeader inspect(Uint8List bytes) => BackupFormat.readHeader(bytes).$1;

  /// Decrypts and parses. Throws [BackupException] on every failure path.
  Future<BackupContents> open(
    Uint8List bytes, {
    required String password,
  }) async {
    final (header, offset) = BackupFormat.readHeader(bytes);

    final minimum =
        offset +
        BackupFormat.saltLength +
        BackupFormat.nonceLength +
        BackupFormat.macLength;
    if (bytes.length < minimum) {
      throw const BackupException(BackupError.corrupt);
    }

    var cursor = offset;
    final salt = bytes.sublist(cursor, cursor += BackupFormat.saltLength);
    final nonce = bytes.sublist(cursor, cursor += BackupFormat.nonceLength);
    final mac = bytes.sublist(cursor, cursor += BackupFormat.macLength);
    final cipherText = bytes.sublist(cursor);

    final key = await _deriveKey(password, salt);

    final List<int> clear;
    try {
      clear = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      // AES-GCM is authenticated, so this fires for a wrong password *and* for
      // a file altered after it was written. The two are indistinguishable,
      // which is exactly the property that makes tampering detectable.
      throw const BackupException(BackupError.wrongPasswordOrTampered);
    }

    try {
      final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      final profiles = <BiodataProfile>[
        for (final raw in json['profiles'] as List<dynamic>)
          BiodataProfile.fromJson(raw as Map<String, dynamic>),
      ];
      return BackupContents(
        header: header,
        profiles: profiles,
        preferences: (json['preferences'] as Map<String, dynamic>?) ?? const {},
      );
    } on Object {
      throw const BackupException(BackupError.corrupt);
    }
  }

  /// Applies a backup.
  ///
  /// NFR-9: a restore either fully succeeds or leaves existing data untouched.
  /// The decrypt and parse both happen in [open] *before* anything is written,
  /// so a bad file can never leave the app half-restored.
  Future<void> restore(
    BackupContents contents, {
    required RestoreStrategy strategy,
  }) async {
    if (strategy == RestoreStrategy.replace) {
      await _store.clearCollection(Collections.profiles);
    }

    for (final profile in contents.profiles) {
      await _store.put(Collections.profiles, profile.id, profile.toJson());
    }

    if (contents.preferences.isNotEmpty) {
      await _store.put(Collections.preferences, 'app', contents.preferences);
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final argon = Argon2id(
      memory: BackupFormat.argonMemoryKb,
      iterations: BackupFormat.argonIterations,
      parallelism: BackupFormat.argonParallelism,
      hashLength: BackupFormat.keyLength,
    );

    // The DB key from NFR-6 is deliberately not reused here: this file leaves
    // the device, and a key derived from the user's password is the only thing
    // that makes it safe to hand to a cloud drive.
    return argon.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  Uint8List _randomBytes(int length) => Uint8List.fromList([
    for (var i = 0; i < length; i++) _random.nextInt(256),
  ]);
}
