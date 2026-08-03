import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:meribiodata/core/storage/encryption_key_store.dart';
import 'package:meribiodata/core/storage/local_store.dart';

/// Hive CE implementation of [LocalStore] (see `docs/decisions.md` D2).
///
/// Every collection is a `Box<String>` of JSON text encrypted with
/// `HiveAesCipher`. Storing JSON rather than registering typed adapters is
/// deliberate: the field engine is schema-driven, so the shape of a profile is
/// data rather than a class, and it keeps Hive types out of the domain layer.
class HiveLocalStore implements LocalStore {
  HiveLocalStore({EncryptionKeyStore? keyStore})
    : _keyStore = keyStore ?? EncryptionKeyStore();

  final EncryptionKeyStore _keyStore;
  final _boxes = <String, Box<String>>{};

  bool _initialised = false;

  @override
  Future<void> init() async {
    if (_initialised) return;

    await Hive.initFlutter('meribiodata');
    final cipher = HiveAesCipher(await _keyStore.getOrCreate());

    for (final collection in Collections.all) {
      _boxes[collection] = await Hive.openBox<String>(
        collection,
        encryptionCipher: cipher,
      );
    }
    _initialised = true;
  }

  Box<String> _box(String collection) {
    final box = _boxes[collection];
    if (box == null) {
      throw StorageException(
        'Unknown collection "$collection". Add it to Collections.all.',
      );
    }
    return box;
  }

  @override
  Future<void> put(
    String collection,
    String id,
    Map<String, dynamic> document,
  ) async {
    try {
      await _box(collection).put(id, jsonEncode(document));
    } on Object catch (e) {
      throw StorageException('Failed to write $collection/$id', e);
    }
  }

  @override
  Future<Map<String, dynamic>?> read(String collection, String id) async {
    final raw = _box(collection).get(id);
    if (raw == null) return null;
    return _decode(raw, '$collection/$id');
  }

  @override
  Future<List<Map<String, dynamic>>> readAll(String collection) async {
    final box = _box(collection);
    return [
      for (final key in box.keys)
        if (box.get(key) case final String raw)
          _decode(raw, '$collection/$key'),
    ];
  }

  @override
  Future<bool> exists(String collection, String id) async =>
      _box(collection).containsKey(id);

  @override
  Future<void> delete(String collection, String id) =>
      _box(collection).delete(id);

  @override
  Future<void> clearCollection(String collection) async {
    await _box(collection).clear();
  }

  @override
  Future<void> wipeEverything() async {
    for (final box in _boxes.values) {
      await box.deleteFromDisk();
    }
    _boxes.clear();
    _initialised = false;
    await _keyStore.destroy();
  }

  @override
  Future<void> close() async {
    await Hive.close();
    _boxes.clear();
    _initialised = false;
  }

  Map<String, dynamic> _decode(String raw, String where) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on Object catch (e) {
      throw StorageException('Corrupt document at $where', e);
    }
  }
}
