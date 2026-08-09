/// Where ad unit IDs come from.
///
/// §8: official Google test unit IDs in debug/dev, real ones supplied at build
/// time via `--dart-define` and **never committed**. Defaulting to the test IDs
/// rather than to an empty string matters — an empty unit id fails at runtime
/// in a way that looks like a bug, whereas a test id always shows a test ad and
/// makes a misconfigured build obvious rather than mysterious.
///
/// In practice the three defines are passed together from a gitignored file:
///
/// ```sh
/// flutter build appbundle --release \
///   --dart-define-from-file=admob.json \
///   -PadmobAppId=ca-app-pub-…~…
/// ```
///
/// The App ID needs its own Gradle flag because it lives in the manifest, which
/// a Dart define cannot reach. See `admob.example.json`.
abstract final class AdConfig {
  /// Google's official Android test units. Safe to commit; safe to ship by
  /// accident, because they can never earn or spend real money.
  static const testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const testInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const testRewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

  static const bannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
    defaultValue: testBannerUnitId,
  );

  static const interstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_UNIT_ID',
    defaultValue: testInterstitialUnitId,
  );

  /// Used to unlock a premium template for a day (#32).
  static const rewardedUnitId = String.fromEnvironment(
    'ADMOB_REWARDED_UNIT_ID',
    defaultValue: testRewardedUnitId,
  );

  /// True when *any* unit is still a test unit. Surfaced so a release build
  /// that forgot the defines can be caught by a test rather than by a user
  /// seeing "Test Ad" on their phone.
  ///
  /// Deliberately an `||`: a build that wired up two units and missed the third
  /// is misconfigured, and reporting it as configured would hide exactly the
  /// mistake this getter exists to catch.
  static bool get isUsingTestUnits =>
      bannerUnitId == testBannerUnitId ||
      interstitialUnitId == testInterstitialUnitId ||
      rewardedUnitId == testRewardedUnitId;

  /// Screens allowed to show a banner (§8): Home and the Form Editor only.
  ///
  /// Deliberately an allowlist rather than a "not on the export screen" denial.
  /// A new screen added later gets no ad by default, which is the safe way for
  /// this list to fail — the export screen's buttons are the highest-value taps
  /// in the app and an ad beside them is an AdMob policy risk, not just a UX
  /// annoyance.
  static const bannerScreens = <String>{'home', 'editor'};

  static bool allowsBannerOn(String screenId) =>
      bannerScreens.contains(screenId);

  // ---------------------------------------------------------------------------
  // Interstitial pacing
  //
  // An interstitial on "Create biodata" sits directly in front of the app's
  // main action, which is the most valuable ad placement and also the easiest
  // one to get an AdMob account suspended over. The three limits below exist to
  // keep it on the right side of that line, and they are constants here rather
  // than magic numbers in the controller so they can be argued about in one
  // place.
  // ---------------------------------------------------------------------------

  /// Creates that are never interrupted, counted over the app's lifetime.
  ///
  /// Someone opening MeriBiodata for the first time is deciding whether the app
  /// is worth their time. An ad before they have seen the form answers that
  /// question badly, and a first-run uninstall costs more than the impression
  /// is worth.
  static const interstitialFreeCreates = 2;

  /// Minimum gap between two interstitials.
  static const interstitialInterval = Duration(minutes: 3);

  /// Hard ceiling per calendar day.
  ///
  /// A matchmaker entering twenty biodatas in an afternoon would otherwise
  /// clear the interval check every single time. Google's policy language is
  /// about ads that interfere with normal use; twenty full-screen ads in one
  /// sitting is that, whatever the interval says.
  static const interstitialDailyCap = 4;

  /// How long a tap may wait for an ad that is still loading.
  ///
  /// Past this the user goes straight to the editor and the ad is dropped. The
  /// rule is absolute: **an ad never prevents or delays making a biodata.** A
  /// slow network must cost the impression, not the user's action.
  static const interstitialLoadTimeout = Duration(milliseconds: 1500);

  /// How long a *rewarded* ad may take to arrive.
  ///
  /// Much longer than the interstitial's budget, because the trade runs the
  /// other way. An interstitial nobody asked for should be dropped rather than
  /// waited on; a rewarded ad was requested by someone who wants the unlock,
  /// and giving up after a second and a half would simply deny them it.
  static const rewardedLoadTimeout = Duration(seconds: 10);
}
