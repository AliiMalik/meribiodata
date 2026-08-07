import 'package:flutter/foundation.dart';
import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/features/ads/ad_config.dart';

/// How often the interstitial is allowed to appear, and the memory of when it
/// last did.
///
/// Split out from the ad controller because it is the part worth testing hard:
/// loading an ad is Google's problem, but deciding whether the user has already
/// seen enough of them today is ours, and getting it wrong is an account
/// suspension rather than a bug report.
///
/// Persisted, deliberately. An in-memory counter resets when the app is killed,
/// which on a mid-range Android phone happens constantly — so the caps would
/// quietly stop applying for exactly the users whose phones are already
/// struggling.
class AdPacing {
  AdPacing(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Its own document rather than a few extra fields on the preferences one:
  /// `PreferencesRepository` rewrites that document wholesale on every save, so
  /// sharing it would mean ad bookkeeping racing the user's settings.
  static const _documentId = 'adPacing';

  static const _keyCreates = 'creates';
  static const _keyLastShownMs = 'lastShownMs';
  static const _keyDay = 'day';
  static const _keyShownToday = 'shownToday';

  final LocalStore _store;
  final DateTime Function() _now;

  int _creates = 0;
  DateTime? _lastShown;
  String _day = '';
  int _shownToday = 0;
  bool _loaded = false;

  @visibleForTesting
  int get shownToday => _sameDay ? _shownToday : 0;

  /// Reads the stored state, at most once.
  ///
  /// Lazy rather than something the caller must remember to await at startup.
  /// If the first `recordCreate()` ran before a load had finished it would save
  /// a count of 1 over the real one, silently handing every user their free
  /// creates back on every launch — the kind of race that never shows up in a
  /// test and never stops happening in production.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final values =
          await _store.read(Collections.preferences, _documentId) ?? const {};
      _creates = values[_keyCreates] as int? ?? 0;
      _shownToday = values[_keyShownToday] as int? ?? 0;
      _day = values[_keyDay] as String? ?? '';
      if (values[_keyLastShownMs] case final int ms) {
        _lastShown = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } on Object catch (error) {
      // Unreadable pacing state must not stop anyone making a biodata. Starting
      // from zero is the wrong-but-safe direction: at worst one extra ad.
      debugPrint('Ad pacing unreadable, starting fresh: $error');
    }
  }

  String get _today {
    final now = _now();
    return '${now.year}-${now.month}-${now.day}';
  }

  bool get _sameDay => _day == _today;

  /// Whether an interstitial may be shown *right now*.
  ///
  /// Three independent limits, all of which must pass. See [AdConfig] for why
  /// each one is there.
  bool get allowsInterstitial {
    if (_creates <= AdConfig.interstitialFreeCreates) return false;
    if (shownToday >= AdConfig.interstitialDailyCap) return false;

    final last = _lastShown;
    if (last == null) return true;

    final since = _now().difference(last);
    // A negative gap means the clock moved backwards — a timezone change, or a
    // user setting the date. Treated as "too soon" rather than "allowed",
    // because the alternative lets anyone bypass the interval by changing the
    // date, and the cost of being wrong is one skipped ad.
    if (since.isNegative) return false;

    return since >= AdConfig.interstitialInterval;
  }

  /// Counted whether or not an ad follows, so the free-creates allowance is
  /// about the user's first few biodatas rather than the first few ads.
  ///
  /// Every caller awaits this before consulting [allowsInterstitial], which is
  /// what makes that getter safe to leave synchronous.
  Future<void> recordCreate() async {
    await load();
    _creates++;
    await _save();
  }

  Future<void> recordInterstitialShown() async {
    final now = _now();
    _shownToday = _sameDay ? _shownToday + 1 : 1;
    _day = _today;
    _lastShown = now;
    await _save();
  }

  Future<void> _save() async {
    try {
      await _store.put(Collections.preferences, _documentId, {
        _keyCreates: _creates,
        _keyShownToday: _shownToday,
        _keyDay: _day,
        if (_lastShown case final DateTime at)
          _keyLastShownMs: at.millisecondsSinceEpoch,
      });
    } on Object catch (error) {
      // Same reasoning as load(): ad bookkeeping is never worth an exception on
      // a path the user reached by tapping "Create biodata".
      debugPrint('Ad pacing not saved: $error');
    }
  }
}
