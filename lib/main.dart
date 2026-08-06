import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meribiodata/app.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/preferences/preferences_repository.dart';
import 'package:meribiodata/core/storage/hive_local_store.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/bundled_roman_urdu.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/text/roman_urdu.dart';
import 'package:meribiodata/features/ads/consent_gate.dart';
import 'package:meribiodata/features/sync/backup_service.dart';
import 'package:meribiodata/features/sync/drive_auth.dart';
import 'package:meribiodata/features/sync/sync_config.dart';
import 'package:meribiodata/features/sync/sync_controller.dart';
import 'package:meribiodata/features/sync/sync_service.dart';

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

  // Consent is resolved in the background rather than awaited: it can involve a
  // network round trip, and blocking first paint on an ad-related call would
  // make the app feel broken offline. The banner appears if and when consent
  // permits (§8, NFR-3).
  final consent = ConsentGate();
  unawaited(consent.resolve());

  // Reads any existing Google session without prompting, so a returning
  // user is simply already connected. Not awaited: it can touch the
  // network, and first paint must not wait on Drive any more than on ads.
  final profiles = ProfileRepository(store);
  final sync = SyncController(
    SyncService(
      backups: BackupService(store),
      auth: GoogleDriveAuth(serverClientId: SyncConfig.webClientId),
    ),
  );
  unawaited(sync.load());

  runApp(
    MeriBiodataApp(
      store: store,
      preferences: preferences,
      profiles: profiles,
      labels: await BundledLabels.load(),
      consent: consent,
      romanUrdu: RomanUrduTransliterator(
        await BundledRomanUrduDictionary.load(),
      ),
      sync: sync,
    ),
  );
}
