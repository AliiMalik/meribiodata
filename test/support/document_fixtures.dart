import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/domain/biodata/biodata_profile.dart';
import 'package:meribiodata/domain/biodata/default_schema.dart';
import 'package:meribiodata/domain/biodata/field_values.dart';
import 'package:meribiodata/domain/render/document_builder.dart';
import 'package:meribiodata/domain/render/rendered_document.dart';

import 'schema_fixtures.dart';

/// Registers the shipped fonts with the test binding.
///
/// Without this every golden renders in Ahem — solid boxes — which would make
/// the Nastaliq goldens worthless as a check on the thing that matters most.
Future<void> loadDocumentFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(
        Future.value(
          ByteData.view(File(path).readAsBytesSync().buffer),
        ),
      );
    }
    await loader.load();
  }

  await load('Inter', [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]);
  await load('NotoNastaliqUrdu', [
    'assets/fonts/NotoNastaliqUrdu-Regular.ttf',
    'assets/fonts/NotoNastaliqUrdu-Bold.ttf',
  ]);
  await load('NotoNaskhArabic', [
    'assets/fonts/NotoNaskhArabic-Regular.ttf',
    'assets/fonts/NotoNaskhArabic-Bold.ttf',
  ]);
}

/// Realistic content per language, including the values that break renderers:
/// a Latin acronym inside RTL prose, a multi-group phone number, and a date.
const _samples = <String, Map<String, Object>>{
  'en': {
    BuiltInKeys.name: 'Muhammad Ali Malik',
    BuiltInKeys.caste: 'Arain',
    BuiltInKeys.occupation: 'Doctor, Government Hospital',
    BuiltInKeys.education: 'MBBS, King Edward Medical University, Lahore',
    BuiltInKeys.fatherName: 'Muhammad Aslam Malik',
    BuiltInKeys.address: 'House 12, Gulberg, Lahore',
    BuiltInKeys.phone: '+92 300 1234567',
  },
  'ur': {
    BuiltInKeys.name: 'محمد علی ملک',
    BuiltInKeys.caste: 'آرائیں',
    BuiltInKeys.occupation: 'ڈاکٹر، سرکاری ہسپتال',
    BuiltInKeys.education: 'ایم بی بی ایس، کنگ ایڈورڈ میڈیکل یونیورسٹی لاہور',
    BuiltInKeys.fatherName: 'محمد اسلم ملک',
    BuiltInKeys.address: 'مکان نمبر 12، گلبرگ، لاہور',
    BuiltInKeys.phone: '+92 300 1234567',
  },
  'sd': {
    BuiltInKeys.name: 'محمد علي سومرو',
    BuiltInKeys.caste: 'سومرو',
    BuiltInKeys.occupation: 'استاد',
    BuiltInKeys.education: 'ايم اي سنڌي، سنڌ يونيورسٽي ڄامشورو',
    BuiltInKeys.fatherName: 'عبدالرحمان سومرو',
    BuiltInKeys.address: 'ڪراچي',
    BuiltInKeys.phone: '+92 300 1234567',
  },
  'ps': {
    BuiltInKeys.name: 'محمد علي خان',
    BuiltInKeys.caste: 'یوسفزی',
    BuiltInKeys.occupation: 'ښوونکی',
    BuiltInKeys.education: 'بي اې، د پېښور پوهنتون',
    BuiltInKeys.fatherName: 'عبدالله خان',
    BuiltInKeys.address: 'پېښور',
    BuiltInKeys.phone: '+92 300 1234567',
  },
};

/// A filled-in profile in [languageCode], with stable ids and dates so the
/// goldens do not churn.
BiodataProfile sampleProfile(String languageCode) {
  final profile = buildTestProfile(documentLanguageCode: languageCode);
  final sample = _samples[languageCode] ?? _samples['en']!;

  final values = <String, dynamic>{
    for (final entry in sample.entries)
      profile.schema.fieldByBuiltInKey(entry.key)!.id: entry.value,
    profile.schema.fieldByBuiltInKey(BuiltInKeys.dob)!.id: DateTime.utc(
      1995,
      3,
      15,
    ).toIso8601String(),
    profile.schema.fieldByBuiltInKey(BuiltInKeys.height)!.id:
        HeightValue.fromFeetInches(5, 9).toJson(),
    profile.schema.fieldByBuiltInKey(BuiltInKeys.brothers)!.id:
        const RepeatableGroupValue(total: 2, marriedCount: 1).toJson(),
  };

  return profile.copyWith(values: values);
}

/// Built with the *shipped* labels, so a golden shows what a user would see —
/// and so a missing translation in `field_labels.json` shows up as a raw id in
/// the image rather than passing quietly.
RenderedDocument sampleDocument(
  String languageCode, {
  required BundledLabels labels,
  ExportMode mode = ExportMode.full,
  String? watermark = 'Made with Pakistani Biodata Maker',
}) => DocumentBuilder(
  labels: labels,
  stringsFor: labels.stringsFor,
  now: DateTime.utc(2026, 8, 4),
).build(sampleProfile(languageCode), mode: mode, watermark: watermark);
