import 'package:flutter/foundation.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/biodata_profile.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';

enum ListStatus { loading, ready, failed }

/// Backs the Home screen's list of saved biodatas (§7.2).
class ProfileListController extends ChangeNotifier {
  ProfileListController(this._repository);

  final ProfileRepository _repository;

  List<BiodataProfile> _all = const [];
  String _query = '';
  ListStatus _status = ListStatus.loading;

  ListStatus get status => _status;
  String get query => _query;
  bool get isEmpty => _all.isEmpty;

  /// Profiles matching the current search, newest edit first.
  List<BiodataProfile> get visible {
    if (_query.trim().isEmpty) return _all;
    final needle = _query.trim().toLowerCase();
    return _all
        .where((p) => _searchableText(p).toLowerCase().contains(needle))
        .toList();
  }

  Future<void> load() async {
    try {
      _all = await _repository.loadAll();
      _status = ListStatus.ready;
    } on Object {
      _status = ListStatus.failed;
    }
    notifyListeners();
  }

  void search(String query) {
    if (query == _query) return;
    _query = query;
    notifyListeners();
  }

  Future<BiodataProfile> createProfile({
    String documentLanguageCode = 'en',
  }) async {
    final profile = _repository.create(
      documentLanguageCode: documentLanguageCode,
    );
    await _repository.save(profile);
    await load();
    return profile;
  }

  Future<void> duplicateProfile(BiodataProfile source, String newName) async {
    await _repository.save(_repository.duplicate(source, newName: newName));
    await load();
  }

  Future<void> deleteProfile(String id) async {
    await _repository.delete(id);
    await load();
  }

  /// Search covers the profile's own name *and* the candidate's name, because
  /// a parent managing three biodatas will search for whichever they remember.
  String _searchableText(BiodataProfile profile) {
    final candidate =
        profile.schema.fieldByBuiltInKey(BuiltInKeys.name)?.id ?? '';
    final name = profile.values[candidate];
    return '${profile.profileName ?? ''} ${name is String ? name : ''}';
  }
}

/// The name to show for a profile in the list: its own label, else the
/// candidate's name, else a placeholder the caller supplies.
String profileDisplayName(BiodataProfile profile, String fallback) {
  final own = profile.profileName?.trim();
  if (own != null && own.isNotEmpty) return own;

  final nameFieldId = profile.schema.fieldByBuiltInKey(BuiltInKeys.name)?.id;
  final candidate = nameFieldId == null ? null : profile.values[nameFieldId];
  if (candidate is String && candidate.trim().isNotEmpty) {
    return candidate.trim();
  }
  return fallback;
}
