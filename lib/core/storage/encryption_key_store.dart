import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce/hive.dart';

/// Owns the 256-bit key that encrypts the local database (NFR-6).
///
/// The key lives in the platform keystore via `flutter_secure_storage` and is
/// never written to the app's own storage, never logged, and never reused for
/// the `.mbd` backup file — that file derives its own key from the user's
/// password (NFR-9).
class EncryptionKeyStore {
  EncryptionKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _keyName = 'meribiodata.db_key.v1';

  final FlutterSecureStorage _storage;

  Uint8List? _cached;

  /// Returns the existing key, generating and persisting one on first run.
  Future<Uint8List> getOrCreate() async {
    final cached = _cached;
    if (cached != null) return cached;

    final existing = await _storage.read(key: _keyName);
    if (existing != null) {
      final key = Uint8List.fromList(base64Decode(existing));
      _cached = key;
      return key;
    }

    final generated = Uint8List.fromList(Hive.generateSecureKey());
    await _storage.write(key: _keyName, value: base64Encode(generated));
    _cached = generated;
    return generated;
  }

  /// Destroys the key. Any data still encrypted with it becomes unreadable,
  /// which is the point — this is part of "delete all my data" (NFR-7).
  Future<void> destroy() async {
    _cached = null;
    await _storage.delete(key: _keyName);
  }
}
