import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:meribiodata/features/ads/ad_config.dart';
import 'package:meribiodata/features/ads/ad_pacing.dart';
import 'package:meribiodata/features/ads/consent_gate.dart';

/// The full-screen ad shown before the biodata editor opens (#30).
///
/// One rule governs everything here, and every branch below is a consequence of
/// it: **the ad must never stop or noticeably delay someone making a biodata.**
/// No consent, no network, no fill, a slow load, a crashed ad SDK — all of them
/// end the same way, with the editor opening. The impression is what gets
/// dropped, never the user's action.
///
/// The ad is therefore *preloaded*. By the time the FAB is tapped an ad is
/// usually already in hand, so the common case shows it instantly and the
/// timeout below is a safety net rather than a normal wait.
class InterstitialAds {
  InterstitialAds({
    required ConsentGate consent,
    required AdPacing pacing,
    bool Function()? isPremium,
    @visibleForTesting InterstitialLoader? loader,
  }) : _isPremium = isPremium ?? _neverPremium,
       _loader = loader ?? const _MobileAdsInterstitialLoader(),
       // The lint's suggested fix does not compile: a named parameter cannot
       // be written `this._consent`, because named parameters may not begin
       // with an underscore. The fields are private and the parameters are
       // not, so this assignment is the only way to spell it.
       // ignore: prefer_initializing_formals
       _consent = consent,
       // Same false positive as above.
       // ignore: prefer_initializing_formals
       _pacing = pacing;

  final ConsentGate _consent;
  final AdPacing _pacing;
  final InterstitialLoader _loader;

  /// A predicate rather than the `Entitlements` object, so the ad layer needs
  /// to know nothing about Play Billing — and so these tests never have to.
  final bool Function() _isPremium;

  static bool _neverPremium() => false;

  InterstitialHandle? _ready;
  Future<InterstitialHandle?>? _loading;
  bool _disposed = false;
  bool _showing = false;

  /// Fetches an ad ahead of time so the next eligible create shows one without
  /// waiting. Safe to call whenever; it does nothing if an ad is already in
  /// hand or on its way.
  void warmUp() {
    if (_disposed || _isPremium() || !_consent.canShowAds) return;
    if (_ready != null || _loading != null) return;

    _loading = _loader
        .load(AdConfig.interstitialUnitId)
        .then((handle) {
          // The timeout path leaves nobody waiting on this future, so a late
          // arrival is kept for next time rather than thrown away.
          if (_disposed) {
            handle?.dispose();
            return null;
          }
          _ready = handle;
          return handle;
        })
        .onError<Object>((error, _) {
          debugPrint('Interstitial failed to load: $error');
          return null;
        })
        .whenComplete(() => _loading = null);
  }

  /// Called on every "Create biodata", whether or not an ad follows.
  ///
  /// Returns once the ad has been dismissed, so the caller can open the editor
  /// straight afterwards without it appearing underneath the ad.
  Future<void> onCreateBiodata() async {
    // Recorded first and unconditionally: the free-creates allowance is about
    // the user's first biodatas, not the first ads, so it has to count the
    // creates made while offline or before consent resolves too.
    await _pacing.recordCreate();

    // Checked after the create is recorded but before anything else: somebody
    // who paid to remove ads gets no ad, and no request goes out on their
    // behalf either.
    if (_disposed || _isPremium() || !_consent.canShowAds) return;

    // A double-tapped FAB runs this twice. Without the guard the second call
    // clears the interval check — it is still running, so nothing has been
    // recorded yet — and the user gets two ads back to back.
    if (_showing) return;

    if (!_pacing.allowsInterstitial) {
      // Not due. Still worth having one ready for when it is.
      warmUp();
      return;
    }

    _showing = true;
    try {
      final handle = await _waitForAd();
      if (handle == null || _disposed) return;

      _ready = null;
      try {
        await handle.show();
        await _pacing.recordInterstitialShown();
      } on Object catch (error) {
        // A failure to display is not the user's problem, and must not become
        // a failure to create a biodata.
        debugPrint('Interstitial failed to show: $error');
      } finally {
        handle.dispose();
      }
    } finally {
      _showing = false;
    }

    warmUp();
  }

  /// An ad if one can be had quickly, null otherwise.
  Future<InterstitialHandle?> _waitForAd() async {
    if (_ready case final InterstitialHandle ready) return ready;

    warmUp();
    final loading = _loading;
    if (loading == null) return null;

    // Bounded wait. The load itself is left running — see warmUp().
    return loading.timeout(
      AdConfig.interstitialLoadTimeout,
      onTimeout: () {
        debugPrint('Interstitial not ready in time; opening the editor');
        return null;
      },
    );
  }

  void dispose() {
    _disposed = true;
    _ready?.dispose();
    _ready = null;
  }
}

/// Loading an interstitial, behind an interface.
///
/// `google_mobile_ads` needs a real Android activity and a network, so none of
/// the pacing or fallback logic above could be tested against it directly.
///
// A one-method interface on purpose: a bare function typedef could not carry
// this explanation, and the fake in the tests needs to count calls.
// ignore: one_member_abstracts
abstract interface class InterstitialLoader {
  /// Completes with null when no ad could be loaded — offline, no fill, or a
  /// misconfigured unit. Never throws.
  Future<InterstitialHandle?> load(String unitId);
}

/// A loaded ad, ready to be shown exactly once.
abstract interface class InterstitialHandle {
  /// Completes when the ad has been **dismissed**, not when it appears.
  Future<void> show();

  void dispose();
}

class _MobileAdsInterstitialLoader implements InterstitialLoader {
  const _MobileAdsInterstitialLoader();

  @override
  Future<InterstitialHandle?> load(String unitId) {
    final completer = Completer<InterstitialHandle?>();

    // Fire-and-forget: the outcome arrives through the callbacks, not through
    // the future this call returns.
    unawaited(
      InterstitialAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (!completer.isCompleted) completer.complete(_LoadedAd(ad));
          },
          onAdFailedToLoad: (error) {
            // No fill is ordinary rather than exceptional — a fresh unit
            // refuses most requests for its first day or two — so this resolves
            // to null instead of throwing.
            debugPrint('Interstitial load failed: $error');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      ),
    );

    return completer.future;
  }
}

class _LoadedAd implements InterstitialHandle {
  _LoadedAd(this._ad);

  final InterstitialAd _ad;
  bool _disposed = false;

  @override
  Future<void> show() {
    final dismissed = Completer<void>();

    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        if (!dismissed.isCompleted) dismissed.complete();
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Interstitial failed to present: $error');
        if (!dismissed.isCompleted) dismissed.complete();
      },
    );

    unawaited(_ad.show());
    return dismissed.future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_ad.dispose());
  }
}
