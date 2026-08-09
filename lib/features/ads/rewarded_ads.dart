import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:meribiodata/features/ads/ad_config.dart';
import 'package:meribiodata/features/ads/consent_gate.dart';

/// How a rewarded ad ended.
enum RewardOutcome {
  /// Watched to the end. This — and only this — grants the unlock.
  earned,

  /// Closed early. Ordinary behaviour, not an error, and nothing is granted.
  dismissed,

  /// No ad to show: offline, no fill, or consent refused. The user must be
  /// told plainly rather than left tapping a button that does nothing.
  unavailable,
}

/// The ad that unlocks a template for a day (D19).
///
/// Unlike the interstitial, this one is **asked for**. The user tapped a locked
/// template and chose to watch it, so the trade here is the opposite: it is
/// worth making them wait a moment for a load, because leaving without an ad
/// means they do not get the thing they just asked for.
///
/// What must never happen is a reward without an ad, or an ad without a reward.
/// The unlock is granted from the SDK's reward callback alone — never from
/// "the ad closed", which also fires for someone who skipped out after two
/// seconds.
class RewardedAds {
  RewardedAds({
    required ConsentGate consent,
    @visibleForTesting RewardedLoader? loader,
  }) : _loader = loader ?? const _MobileAdsRewardedLoader(),
       // A named parameter cannot be written `this._consent`, so the lint's
       // suggested fix does not compile.
       // ignore: prefer_initializing_formals
       _consent = consent;

  final ConsentGate _consent;
  final RewardedLoader _loader;

  RewardedHandle? _ready;
  Future<RewardedHandle?>? _loading;
  bool _showing = false;
  bool _disposed = false;

  /// Whether an ad could plausibly be offered. False hides the "watch an ad"
  /// door entirely rather than showing one that fails when tapped.
  bool get isAvailable => !_disposed && _consent.canShowAds;

  /// Fetches one ahead of time. Called when the picker opens, so the sheet
  /// usually has an ad in hand by the time somebody taps a locked template.
  void warmUp() {
    if (!isAvailable || _ready != null || _loading != null) return;

    _loading = _loader
        .load(AdConfig.rewardedUnitId)
        .then((handle) {
          if (_disposed) {
            handle?.dispose();
            return null;
          }
          _ready = handle;
          return handle;
        })
        .onError<Object>((error, _) {
          debugPrint('Rewarded ad failed to load: $error');
          return null;
        })
        .whenComplete(() => _loading = null);
  }

  /// Shows the ad and reports what the user actually did.
  Future<RewardOutcome> show() async {
    if (!isAvailable || _showing) return RewardOutcome.unavailable;

    _showing = true;
    try {
      final handle = await _obtain();
      if (handle == null || _disposed) return RewardOutcome.unavailable;

      _ready = null;
      try {
        final earned = await handle.show();
        return earned ? RewardOutcome.earned : RewardOutcome.dismissed;
      } on Object catch (error) {
        debugPrint('Rewarded ad failed to present: $error');
        return RewardOutcome.unavailable;
      } finally {
        handle.dispose();
      }
    } finally {
      _showing = false;
      // Ready for the next locked template they try.
      warmUp();
    }
  }

  Future<RewardedHandle?> _obtain() async {
    if (_ready case final RewardedHandle ready) return ready;

    warmUp();
    final loading = _loading;
    if (loading == null) return null;

    // Longer than the interstitial's budget, and deliberately so: this ad was
    // requested, and giving up after a second and a half would deny the user
    // the unlock they just chose to earn.
    return loading.timeout(
      AdConfig.rewardedLoadTimeout,
      onTimeout: () {
        debugPrint('Rewarded ad did not arrive in time');
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

/// Loading a rewarded ad, behind an interface so the unlock rules can be
/// tested without a device.
// One method on purpose: a bare typedef could not carry this explanation, and
// the fake needs to count calls.
// ignore: one_member_abstracts
abstract interface class RewardedLoader {
  /// Null when no ad could be loaded. Never throws.
  Future<RewardedHandle?> load(String unitId);
}

abstract interface class RewardedHandle {
  /// Shows the ad; completes with true only if the reward was earned.
  Future<bool> show();

  void dispose();
}

class _MobileAdsRewardedLoader implements RewardedLoader {
  const _MobileAdsRewardedLoader();

  @override
  Future<RewardedHandle?> load(String unitId) {
    final completer = Completer<RewardedHandle?>();

    unawaited(
      RewardedAd.load(
        adUnitId: unitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (!completer.isCompleted) completer.complete(_LoadedRewarded(ad));
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded load failed: $error');
            if (!completer.isCompleted) completer.complete(null);
          },
        ),
      ),
    );

    return completer.future;
  }
}

class _LoadedRewarded implements RewardedHandle {
  _LoadedRewarded(this._ad);

  final RewardedAd _ad;
  bool _disposed = false;

  @override
  Future<bool> show() {
    final finished = Completer<bool>();
    var earned = false;

    _ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        // Resolved on dismissal rather than on the reward, so closing early
        // settles this future too instead of hanging the sheet forever.
        if (!finished.isCompleted) finished.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Rewarded failed to present: $error');
        if (!finished.isCompleted) finished.complete(false);
      },
    );

    unawaited(
      _ad.show(
        onUserEarnedReward: (_, _) => earned = true,
      ),
    );
    return finished.future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_ad.dispose());
  }
}
