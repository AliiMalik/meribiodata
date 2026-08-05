/// Public URLs the app links out to.
///
/// Build-time constants rather than secrets — these are pages anyone can read,
/// and Play requires the privacy policy to be reachable from the store listing
/// as well as from inside the app.
abstract final class LegalLinks {
  /// Source of the page lives in `docs/privacy/index.html`; the content it has
  /// to carry is reasoned out in `docs/privacy-policy-requirements.md`.
  static const privacyPolicy = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://meribiodata-privacy.example/placeholder',
  );

  /// Guards the same way the waitlist URL does: a test asserts this is still
  /// true, so the day a real URL lands the test fails and asks to be updated.
  static bool get isPlaceholder =>
      privacyPolicy.contains('placeholder') ||
      privacyPolicy.contains('example');
}
