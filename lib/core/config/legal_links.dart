/// Public URLs the app links out to.
///
/// Build-time constants rather than secrets — these are pages anyone can read,
/// and Play requires the privacy policy to be reachable from the store listing
/// as well as from inside the app.
abstract final class LegalLinks {
  /// The page's source lives in `docs/privacy/index.html`; what it has to say
  /// is reasoned out in `docs/privacy-policy-requirements.md`.
  ///
  /// Hosted on Firebase Hosting, deployed with `firebase deploy --only
  /// hosting`. GitHub Pages was tried first and abandoned: builds succeeded but
  /// every deployment was cancelled server-side, through both the Actions and
  /// the branch builder. Firebase served the same file first time.
  ///
  /// Still overridable at build time, so moving to a custom domain later is a
  /// build flag rather than a code change.
  static const privacyPolicy = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://meribiodata.web.app',
  );
}
