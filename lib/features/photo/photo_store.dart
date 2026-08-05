import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Resolves the app's private directory. Injected so tests can point at a
/// temporary directory instead of needing a platform behind `path_provider`.
typedef BaseDirectory = Future<Directory> Function();

/// Where candidate photos live on disk (9.3).
///
/// Two deliberate properties:
///
/// **Outside the shared directory.** Exports live in `exports/`, which is the
/// only path `file_paths.xml` lets the FileProvider hand to another app.
/// Photos live in `photos/`, a sibling, so no share intent can ever reach one.
/// The only way a photo leaves this phone is inside a document the user chose
/// to export with the photo switched on.
///
/// **Stored as a relative path.** Android moves an app's private directory
/// between installs and on some OS upgrades, so an absolute path saved into a
/// profile goes stale — and a profile restored from a backup would point at
/// another device's filesystem. The profile stores `photos/<uuid>.jpg` and this
/// class resolves it at read time.
class PhotoStore {
  const PhotoStore({this.uuid = const Uuid(), this.base = _appSupport});

  final Uuid uuid;
  final BaseDirectory base;

  static const directoryName = 'photos';

  static Future<Directory> _appSupport() => getApplicationSupportDirectory();

  Future<Directory> directory() async {
    final dir = Directory('${(await base()).path}/$directoryName');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Writes [jpeg] under a fresh name and returns the relative path to store.
  ///
  /// A new name every time rather than one per profile: replacing a photo while
  /// the old one is still on screen would otherwise show the old pixels from
  /// the image cache, keyed by a path that no longer means what it did.
  Future<String> save(Uint8List jpeg) async {
    final dir = await directory();
    final name = '${uuid.v4()}.jpg';
    await File('${dir.path}/$name').writeAsBytes(jpeg);
    return '$directoryName/$name';
  }

  /// Writes at an exact relative path. Used by a restore, where the path is
  /// already recorded inside the profile being restored.
  Future<void> writeAt(String relativePath, Uint8List jpeg) async {
    final file = await fileFor(relativePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(jpeg);
  }

  Future<File> fileFor(String relativePath) async =>
      File('${(await base()).path}/$relativePath');

  /// Null when the file is gone — a restored backup from before photos were
  /// included, or a user who cleared app storage. Callers show "add a photo"
  /// rather than an error, because a missing photo is not a broken profile.
  Future<Uint8List?> read(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return null;
    final file = await fileFor(relativePath);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  Future<void> delete(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    final file = await fileFor(relativePath);
    if (file.existsSync()) await file.delete();
  }

  /// Removes every stored photo. Part of "delete all my data" (NFR-7).
  Future<void> deleteAll() async {
    final dir = await directory();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }
}
