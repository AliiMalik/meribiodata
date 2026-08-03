import 'dart:convert';

import 'package:meribiodata/core/storage/local_store.dart';

/// In-memory [LocalStore] for tests.
///
/// Round-trips documents through JSON exactly as the Hive implementation does,
/// so a test will catch anything that is not JSON-serializable.
class InMemoryLocalStore implements LocalStore {
  final _data = <String, Map<String, String>>{};

  bool wiped = false;

  Map<String, String> _collection(String name) =>
      _data.putIfAbsent(name, () => <String, String>{});

  @override
  Future<void> init() async {
    Collections.all.forEach(_collection);
  }

  @override
  Future<void> put(
    String collection,
    String id,
    Map<String, dynamic> document,
  ) async {
    _collection(collection)[id] = jsonEncode(document);
  }

  @override
  Future<Map<String, dynamic>?> read(String collection, String id) async {
    final raw = _collection(collection)[id];
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<List<Map<String, dynamic>>> readAll(String collection) async => [
    for (final raw in _collection(collection).values)
      jsonDecode(raw) as Map<String, dynamic>,
  ];

  @override
  Future<bool> exists(String collection, String id) async =>
      _collection(collection).containsKey(id);

  @override
  Future<void> delete(String collection, String id) async {
    _collection(collection).remove(id);
  }

  @override
  Future<void> clearCollection(String collection) async {
    _collection(collection).clear();
  }

  @override
  Future<void> wipeEverything() async {
    _data.clear();
    wiped = true;
  }

  @override
  Future<void> close() async {}
}
