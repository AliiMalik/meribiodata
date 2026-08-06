import 'dart:convert';
import 'dart:typed_data';

/// Why a restore was refused.
enum BackupError {
  /// Not a `.mbd` file at all.
  notABackup,

  /// Written by a newer app than this one. Refused rather than guessed at.
  futureVersion,

  /// Wrong password, or the file was altered after it was written. AES-GCM
  /// cannot tell these apart, and neither can we.
  wrongPasswordOrTampered,

  /// Truncated or otherwise unreadable.
  corrupt,
}

class BackupException implements Exception {
  const BackupException(this.error);

  final BackupError error;

  @override
  String toString() => 'BackupException: ${error.name}';
}

/// What a restore can tell the user *before* they commit to it.
///
/// 9.5 requires a preview — profile count, creation date, app version — so the
/// user can see what they are about to merge or replace. All of it lives in
/// the plaintext header, which is why the header is not encrypted.
class BackupHeader {
  const BackupHeader({
    required this.formatVersion,
    required this.appVersion,
    required this.createdAt,
    required this.profileCount,
  });

  factory BackupHeader.fromJson(Map<String, dynamic> json) => BackupHeader(
    formatVersion: json['formatVersion'] as int,
    appVersion: json['appVersion'] as String? ?? 'unknown',
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    profileCount: json['profileCount'] as int? ?? 0,
  );

  final int formatVersion;
  final String appVersion;
  final DateTime createdAt;
  final int profileCount;

  Map<String, dynamic> toJson() => {
    'formatVersion': formatVersion,
    'appVersion': appVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'profileCount': profileCount,
  };
}

/// The on-disk layout of a `.mbd` file.
///
/// ```text
///   magic      8 bytes   "MERIBDTA"
///   headerLen  4 bytes   big-endian
///   header     N bytes   UTF-8 JSON, PLAINTEXT (see BackupHeader)
///   salt      16 bytes   random, per file
///   nonce     12 bytes   random, per file
///   mac       16 bytes   AES-GCM authentication tag
///   payload   rest       AES-256-GCM ciphertext
/// ```
///
/// The header is deliberately outside the encryption so a restore can preview
/// the file and reject a future version *before* asking for a password. It
/// carries no personal data — only counts and versions.
abstract final class BackupFormat {
  static const String magic = 'MERIBDTA';

  /// Bumped when the layout changes. Versioned from day one so a v2 file
  /// loaded by a v1 app fails with a clear message instead of corrupting data.
  static const int currentVersion = 1;

  static const magicLength = 8;
  static const headerLengthBytes = 4;
  static const saltLength = 16;
  static const nonceLength = 12;
  static const macLength = 16;

  /// Argon2id parameters.
  ///
  /// 64 MB and three passes is deliberately slow — roughly a second on a
  /// budget phone. This runs once per backup or restore, and the cost is what
  /// makes a weak password expensive to attack offline once the file is
  /// sitting in someone's cloud drive.
  static const int argonMemoryKb = 64 * 1024;
  static const argonIterations = 3;
  static const argonParallelism = 1;
  static const keyLength = 32;

  static Uint8List buildPreamble(BackupHeader header) {
    final headerBytes = utf8.encode(jsonEncode(header.toJson()));
    final builder = BytesBuilder()
      ..add(utf8.encode(magic))
      ..add(
        Uint8List(headerLengthBytes)
          ..buffer.asByteData().setUint32(0, headerBytes.length),
      )
      ..add(headerBytes);
    return builder.toBytes();
  }

  /// Reads the plaintext header without needing the password.
  ///
  /// Throws [BackupException] rather than returning null so every caller has
  /// to decide what to tell the user.
  static (BackupHeader header, int offset) readHeader(Uint8List bytes) {
    if (bytes.length < magicLength + headerLengthBytes) {
      throw const BackupException(BackupError.notABackup);
    }
    if (utf8.decode(bytes.sublist(0, magicLength), allowMalformed: true) !=
        magic) {
      throw const BackupException(BackupError.notABackup);
    }

    final headerLength = ByteData.sublistView(
      bytes,
      magicLength,
      magicLength + headerLengthBytes,
    ).getUint32(0);

    const headerStart = magicLength + headerLengthBytes;
    final headerEnd = headerStart + headerLength;
    if (headerEnd > bytes.length) {
      throw const BackupException(BackupError.corrupt);
    }

    final BackupHeader header;
    try {
      header = BackupHeader.fromJson(
        jsonDecode(utf8.decode(bytes.sublist(headerStart, headerEnd)))
            as Map<String, dynamic>,
      );
    } on Object {
      throw const BackupException(BackupError.corrupt);
    }

    if (header.formatVersion > currentVersion) {
      throw const BackupException(BackupError.futureVersion);
    }

    return (header, headerEnd);
  }
}
