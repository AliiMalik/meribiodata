/// Build-time configuration for Drive sync.
abstract final class SyncConfig {
  /// The **web** OAuth client ID from the Google Cloud project.
  ///
  /// Not a secret. An installed Android app cannot keep one, which is why
  /// Google's model does not rely on it: what actually authorises this app is
  /// the package name plus the signing certificate fingerprint, registered
  /// against Android OAuth clients that are never named in code. This value
  /// only identifies the Cloud project.
  ///
  /// Overridable at build time so a fork, or a second Cloud project, needs no
  /// code change:
  ///   flutter build appbundle --dart-define=GOOGLE_WEB_CLIENT_ID=…
  static const webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '82528716311-vqcer67t83te9fcp8jmidvmghcc37990'
        '.apps.googleusercontent.com',
  );

  /// How long the app waits after the last edit before uploading.
  ///
  /// Long enough that filling in a form is one upload rather than thirty,
  /// short enough that putting the phone down and losing it costs nothing.
  static const debounce = Duration(seconds: 20);
}
