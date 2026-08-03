/// Storage-engine-agnostic document store.
///
/// Everything the app persists is a plain JSON map. No storage-engine type
/// (Hive box, adapter, `TypeId`, …) may cross this boundary — see
/// `docs/decisions.md` D2. That keeps the engine swappable and makes the 9.5
/// encrypted backup a straight serialization of the same documents.
abstract interface class LocalStore {
  /// Opens the underlying storage. Safe to call more than once.
  Future<void> init();

  Future<void> put(String collection, String id, Map<String, dynamic> document);

  Future<Map<String, dynamic>?> read(String collection, String id);

  Future<List<Map<String, dynamic>>> readAll(String collection);

  Future<bool> exists(String collection, String id);

  Future<void> delete(String collection, String id);

  Future<void> clearCollection(String collection);

  /// Irreversibly removes every collection *and* the encryption key.
  /// Backs the "delete all my data" requirement (NFR-7).
  Future<void> wipeEverything();

  Future<void> close();
}

/// Collection names. Kept here rather than as string literals at call sites so
/// a rename is one edit and a typo is a compile error.
abstract final class Collections {
  static const profiles = 'profiles';
  static const schemas = 'schemas';
  static const preferences = 'preferences';

  static const all = <String>[profiles, schemas, preferences];
}

class StorageException implements Exception {
  const StorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'StorageException: $message${cause == null ? '' : ' ($cause)'}';
}
