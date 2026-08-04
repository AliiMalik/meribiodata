import 'package:meribiodata/domain/biodata/biodata_profile.dart';
import 'package:meribiodata/domain/biodata/biodata_schema.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/label_resolver.dart';

/// Deterministic ids so failures point at a field rather than a random UUID.
IdGenerator sequentialIds([String prefix = 'id']) {
  var next = 0;
  return () => '$prefix-${next++}';
}

BiodataSchema buildTestSchema([String prefix = 'id']) =>
    DefaultSchema.build(newId: sequentialIds(prefix));

BiodataProfile buildTestProfile({
  String id = 'profile-1',
  String? profileName,
  String documentLanguageCode = 'en',
  Map<String, dynamic> values = const {},
}) {
  final now = DateTime.utc(2026, 8, 4);
  return BiodataProfile(
    id: id,
    schema: buildTestSchema(),
    createdAt: now,
    updatedAt: now,
    profileName: profileName,
    documentLanguageCode: documentLanguageCode,
    values: values,
  );
}

/// A [BuiltInLabels] with just enough entries for tests, so they do not depend
/// on the shipped asset file's exact contents.
class FakeBuiltInLabels implements BuiltInLabels {
  const FakeBuiltInLabels([this.fields = const {}, this.sections = const {}]);

  /// `builtInKey` → locale → label.
  final Map<String, Map<String, String>> fields;
  final Map<String, Map<String, String>> sections;

  static const standard = FakeBuiltInLabels(
    {
      BuiltInKeys.caste: {'en': 'Caste / Biradari', 'ur': 'ذات / برادری'},
      BuiltInKeys.name: {'en': 'Name', 'ur': 'نام'},
      // Deliberately English-only, to exercise the English fallback step.
      BuiltInKeys.bloodGroup: {'en': 'Blood Group'},
    },
    {
      BuiltInKeys.personal: {'en': 'Personal Details', 'ur': 'ذاتی معلومات'},
    },
  );

  @override
  String? fieldLabel(String builtInKey, String localeCode) =>
      fields[builtInKey]?[localeCode];

  @override
  String? sectionTitle(String builtInKey, String localeCode) =>
      sections[builtInKey]?[localeCode];
}
