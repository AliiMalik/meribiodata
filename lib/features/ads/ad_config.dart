/// Where ad unit IDs come from.
///
/// §8: official Google test unit IDs in debug/dev, real ones supplied at build
/// time via `--dart-define` and **never committed**. Defaulting to the test IDs
/// rather than to an empty string matters — an empty unit id fails at runtime
/// in a way that looks like a bug, whereas a test id always shows a test ad and
/// makes a misconfigured build obvious rather than mysterious.
abstract final class AdConfig {
  /// Google's official Android banner test unit. Safe to commit; safe to ship
  /// by accident, because it can never earn or spend real money.
  static const testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';

  /// Supplied as:
  ///   flutter build appbundle --dart-define=ADMOB_BANNER_UNIT_ID=ca-app-pub-…
  static const bannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_UNIT_ID',
    defaultValue: testBannerUnitId,
  );

  /// True when the build is using test units. Surfaced so a release build that
  /// forgot the define can be caught by a test rather than by a user seeing
  /// "Test Ad" on their phone.
  static bool get isUsingTestUnits => bannerUnitId == testBannerUnitId;

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
}
