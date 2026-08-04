import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/domain/biodata/biodata_profile.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:uuid/uuid.dart';

/// Reads and writes biodata profiles.
///
/// The only place that knows profiles are persisted at all. Ids are always
/// UUIDs — Hive encrypts values but not keys, so a user-derived id would leak
/// a name onto disk in plaintext (`docs/decisions.md` D2).
class ProfileRepository {
  ProfileRepository(this._store, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final LocalStore _store;
  final Uuid _uuid;

  String newId() => _uuid.v4();

  Future<List<BiodataProfile>> loadAll() async {
    final documents = await _store.readAll(Collections.profiles);
    final profiles = <BiodataProfile>[];
    for (final document in documents) {
      // One unreadable profile must not hide the rest. A biodata the user
      // spent ten minutes on is worth more than a clean failure.
      try {
        profiles.add(BiodataProfile.fromJson(document));
      } on Object {
        continue;
      }
    }
    return profiles..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<BiodataProfile?> load(String id) async {
    final document = await _store.read(Collections.profiles, id);
    if (document == null) return null;
    return BiodataProfile.fromJson(document);
  }

  Future<void> save(BiodataProfile profile) => _store.put(
    Collections.profiles,
    profile.id,
    profile.copyWith(updatedAt: DateTime.now()).toJson(),
  );

  Future<void> delete(String id) => _store.delete(Collections.profiles, id);

  /// A brand-new biodata, seeded with the default schema (§6.2, D6).
  BiodataProfile create({
    String? profileName,
    String documentLanguageCode = 'en',
  }) {
    final now = DateTime.now();
    return BiodataProfile(
      id: newId(),
      schema: DefaultSchema.build(newId: newId),
      createdAt: now,
      updatedAt: now,
      profileName: profileName,
      documentLanguageCode: documentLanguageCode,
    );
  }

  /// Copies a profile, including its schema and answers.
  ///
  /// Field ids are **kept**, not regenerated: the values map is keyed by them,
  /// and the copy has its own document so there is no collision. Regenerating
  /// them would mean rewriting every value key for no benefit.
  BiodataProfile duplicate(BiodataProfile source, {required String newName}) {
    final now = DateTime.now();
    return source.copyWith(
      id: newId(),
      profileName: newName,
      createdAt: now,
      updatedAt: now,
    );
  }
}
