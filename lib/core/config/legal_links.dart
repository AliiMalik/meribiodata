/// Public URLs the app links out to.
///
/// Build-time constants rather than secrets — these are pages anyone can read,
/// and Play requires the privacy policy to be reachable from the store listing
/// as well as from inside the app.
abstract final class LegalLinks {
  /// Source of the page lives in `docs/privacy/index.html`; the content it has
  /// to carry is reasoned out in `docs/privacy-policy-requirements.md`.
  /// Served by `.github/workflows/publish-privacy.yml` from `docs/privacy/`.
  /// Still overridable at build time so a fork, or a move to a custom domain,
  /// needs no code change.
  static const privacyPolicy = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://aliimalik.github.io/meribiodata/',
  );
}
