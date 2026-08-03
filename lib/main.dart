import 'package:flutter/material.dart';
import 'package:meribiodata/app.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/preferences/preferences_repository.dart';
import 'package:meribiodata/core/storage/hive_local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _start();
}

Future<void> _start() async {
  final store = HiveLocalStore();
  try {
    await store.init();
  } on Object catch (error, stack) {
    debugPrint('Storage init failed: $error\n$stack');
    runApp(const StorageFailureApp(onRetry: _start));
    return;
  }

  final preferences = AppPreferences(PreferencesRepository(store));
  await preferences.load();

  runApp(MeriBiodataApp(store: store, preferences: preferences));
}
