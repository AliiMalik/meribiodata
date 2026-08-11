import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:meribiodata/features/sync/drive_auth.dart';

/// What is sitting in Drive, without downloading it.
class RemoteBackup {
  const RemoteBackup({
    required this.fileId,
    required this.modifiedAt,
    required this.bytes,
  });

  final String fileId;
  final DateTime modifiedAt;

  /// File size. Named for what it is at the transport layer; the contents are
  /// an encrypted blob this class knows nothing about.
  final int bytes;
}

/// Reads and writes the single backup file in the user's Drive.
///
/// Deliberately narrow: one file, one name, no folders, no listing of anything
/// the app did not create. The `drive.file` scope makes that a hard boundary
/// rather than a convention — a query here *cannot* return the user's other
/// documents, because Google will not include them.
///
/// Knows nothing about encryption. It moves opaque bytes, which is what keeps
/// "we cannot read your backup" true at this layer too.
class DriveClient {
  DriveClient(
    this._identity, {
    http.Client? httpClient,
    // Private field; Dart forbids a named parameter starting with an
    // underscore, so `this._httpClient` is not available here.
    // ignore: prefer_initializing_formals
  }) : _httpClient = httpClient;

  /// The name shown in the user's Drive. They chose a visible scope, so this
  /// is a thing a real person will see and should be able to recognise.
  /// What the user sees sitting in their own Drive, so it is written the way a
  /// person would read it rather than as an identifier.
  ///
  /// Safe to rename only because nothing has shipped: the app is not published
  /// and Drive sync has never run against a real account, so no file exists
  /// anywhere under the old name. Renaming after release would orphan every
  /// backup, since lookup is by exact name.
  static const fileName = 'Pak Marriage Biodata Maker backup.mbd';

  final DriveIdentity _identity;
  final http.Client? _httpClient;

  Future<T> _withApi<T>(Future<T> Function(drive.DriveApi api) body) async {
    final inner = _httpClient ?? http.Client();
    final client = DriveHttpClient(_identity.accessToken, inner);
    try {
      return await body(drive.DriveApi(client));
    } finally {
      // Closing the wrapper closes the inner client too. Only close one we
      // created — an injected client belongs to the caller.
      if (_httpClient == null) client.close();
    }
  }

  /// The existing backup, or null if this account has never had one.
  Future<RemoteBackup?> find() => _withApi((api) async {
    final result = await api.files.list(
      q: "name = '$fileName' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, modifiedTime, size)',
      pageSize: 10,
    );

    final files = result.files ?? const <drive.File>[];
    if (files.isEmpty) return null;

    // Newest wins. Duplicates should not happen — the app updates in place —
    // but a user restoring an old copy by hand could create one, and silently
    // picking an arbitrary file would be the worse failure.
    files.sort(
      (a, b) => (b.modifiedTime ?? DateTime(0)).compareTo(
        a.modifiedTime ?? DateTime(0),
      ),
    );
    final newest = files.first;

    return RemoteBackup(
      fileId: newest.id!,
      modifiedAt: newest.modifiedTime ?? DateTime.now(),
      bytes: int.tryParse(newest.size ?? '0') ?? 0,
    );
  });

  /// Writes [data], replacing the existing file's contents when there is one.
  ///
  /// Updating in place rather than creating a new file each time matters: it
  /// keeps one entry in the user's Drive instead of a growing pile, and it
  /// keeps the file's own sharing and location settings if they moved it.
  Future<RemoteBackup> upload(Uint8List data) => _withApi((api) async {
    // No contentType: the default is already application/octet-stream, which
    // is exactly what an encrypted blob is.
    final media = drive.Media(Stream.value(data), data.length);

    final existing = await find();
    final drive.File saved;
    if (existing == null) {
      saved = await api.files.create(
        drive.File()
          ..name = fileName
          ..description =
              'Encrypted MeriBiodata backup. Only the MeriBiodata app, with '
              'your password, can read this.',
        uploadMedia: media,
        $fields: 'id, modifiedTime, size',
      );
    } else {
      saved = await api.files.update(
        drive.File(),
        existing.fileId,
        uploadMedia: media,
        $fields: 'id, modifiedTime, size',
      );
    }

    return RemoteBackup(
      fileId: saved.id!,
      modifiedAt: saved.modifiedTime ?? DateTime.now(),
      bytes: int.tryParse(saved.size ?? '${data.length}') ?? data.length,
    );
  });

  Future<Uint8List> download(String fileId) => _withApi((api) async {
    final media =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final chunks = <int>[];
    await media.stream.forEach(chunks.addAll);
    return Uint8List.fromList(chunks);
  });
}
