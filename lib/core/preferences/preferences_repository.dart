import 'package:meribiodata/core/storage/local_store.dart';

/// App-wide preferences, persisted as a single document.
///
/// Kept as a plain map at the storage boundary so the 9.5 backup can carry
/// preferences verbatim without a second serialization path.
class PreferencesRepository {
  const PreferencesRepository(this._store);

  static const _documentId = 'app';

  final LocalStore _store;

  Future<Map<String, dynamic>> load() async =>
      await _store.read(Collections.preferences, _documentId) ?? const {};

  Future<void> save(Map<String, dynamic> values) =>
      _store.put(Collections.preferences, _documentId, values);
}
