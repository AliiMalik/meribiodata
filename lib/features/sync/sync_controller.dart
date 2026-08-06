import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meribiodata/features/sync/drive_client.dart';
import 'package:meribiodata/features/sync/sync_config.dart';
import 'package:meribiodata/features/sync/sync_service.dart';

/// What the app is doing about sync right now.
enum SyncStatus {
  /// Not connected to an account. Nothing is being backed up.
  off,

  /// Connected and up to date.
  idle,

  /// Changes are waiting for the debounce to elapse.
  pending,

  /// Uploading.
  syncing,

  /// The last attempt failed. [SyncController.problem] says why.
  failed,
}

/// Drives Drive sync and is the single thing the UI listens to.
///
/// Deliberately shaped like `ProfileEditorController`: schedule on change,
/// debounce, flush on the way out. Sync is the same problem as autosave with a
/// slower and less reliable destination, so it should not look like a different
/// one.
class SyncController extends ChangeNotifier {
  SyncController(
    this._service, {
    this.debounce = SyncConfig.debounce,
  });

  final SyncService _service;

  /// How long to wait after the last change. Shortened in tests.
  final Duration debounce;

  Timer? _timer;
  bool _disposed = false;

  SyncStatus _status = SyncStatus.off;
  SyncProblem? _problem;
  String? _account;
  DateTime? _lastSyncedAt;

  SyncStatus get status => _status;

  /// Why the last attempt failed. Null unless [status] is [SyncStatus.failed].
  SyncProblem? get problem => _problem;

  /// The signed-in Google account, or null when sync is off.
  String? get account => _account;

  DateTime? get lastSyncedAt => _lastSyncedAt;

  bool get isConnected => _account != null;

  /// Reads the existing session without prompting. Safe to call at startup.
  Future<void> load() async {
    final identity = await _service.currentAccount();
    _account = identity?.email;
    _status = identity == null ? SyncStatus.off : SyncStatus.idle;

    // Connected but with no password means a half-finished setup — the user
    // signed in and then backed out of choosing one. Surfaced rather than
    // hidden, because otherwise nothing would ever upload and nothing would
    // say why.
    if (identity != null && !await _service.hasPassword()) {
      _status = SyncStatus.failed;
      _problem = SyncProblem.needsPassword;
    }
    _notify();
  }

  /// Prompts for a Google account and the Drive permission.
  Future<bool> connect() async {
    final identity = await _service.signIn();
    if (identity == null) return false;

    _account = identity.email;
    _status = await _service.hasPassword()
        ? SyncStatus.idle
        : SyncStatus.failed;
    _problem = _status == SyncStatus.failed ? SyncProblem.needsPassword : null;
    _notify();
    return true;
  }

  Future<void> disconnect() async {
    _timer?.cancel();
    await _service.disconnect();
    _account = null;
    _status = SyncStatus.off;
    _problem = null;
    _lastSyncedAt = null;
    _notify();
  }

  Future<void> setPassword(String password) async {
    await _service.setPassword(password);
    if (_problem == SyncProblem.needsPassword) {
      _status = SyncStatus.idle;
      _problem = null;
    }
    _notify();
    // A password is only ever set at a moment when the user expects something
    // to happen, so prove it works immediately rather than waiting.
    await syncNow();
  }

  /// Call after anything that changed stored data.
  ///
  /// Cheap and idempotent — it only starts a timer. When sync is off it does
  /// nothing at all, so callers never have to check first.
  void scheduleSync() {
    if (!isConnected) return;

    _status = SyncStatus.pending;
    _notify();

    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(syncNow()));
  }

  /// Uploads now, cancelling any pending debounce.
  Future<void> syncNow() async {
    if (!isConnected) return;

    _timer?.cancel();
    _status = SyncStatus.syncing;
    _problem = null;
    _notify();

    try {
      final remote = await _service.push();
      _lastSyncedAt = remote.modifiedAt;
      _status = SyncStatus.idle;
    } on SyncException catch (e) {
      _problem = e.problem;
      _status = SyncStatus.failed;
      // Offline is the common case and not worth a log line every time.
      if (e.problem != SyncProblem.driveUnavailable) {
        debugPrint('Sync failed: $e');
      }
    } on Object catch (e, stack) {
      _problem = SyncProblem.driveUnavailable;
      _status = SyncStatus.failed;
      debugPrint('Sync failed unexpectedly: $e\n$stack');
    }
    _notify();
  }

  /// Uploads immediately if anything is outstanding. Called when the app is
  /// backgrounded, so a pending change is not lost with the phone.
  Future<void> flush() async {
    if (_status != SyncStatus.pending) return;
    await syncNow();
  }

  /// What is in Drive, without downloading or decrypting it.
  Future<RemoteBackup?> peek() => _service.peek();

  /// The service itself, for the restore flow — that is a multi-step
  /// conversation with the user rather than a state this controller holds.
  SyncService get service => _service;

  /// The final flush outlives the widget that started it, so the write must
  /// complete but the notification must not fire.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
