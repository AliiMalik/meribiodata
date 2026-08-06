import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

/// Who is signed in, and what the app is allowed to do on their behalf.
class DriveIdentity {
  const DriveIdentity({required this.email, required this.accessToken});

  final String email;

  /// Short-lived. Never persisted — it is fetched again on every sync, because
  /// a stored token is a stored credential and this app has enough of those.
  final String accessToken;
}

/// Raised when the user is signed in but has not granted the Drive scope, or
/// withdrew it later. Distinct from "not signed in", because the recovery is
/// different: one needs a sign-in, the other needs a consent prompt.
class DriveAuthorizationNeeded implements Exception {
  const DriveAuthorizationNeeded();
}

/// Google sign-in and Drive authorization, behind an interface.
///
/// An interface rather than a direct dependency because `google_sign_in`
/// cannot run in a unit test — it needs a real activity, a real Google account
/// and a real network. Everything above this layer is testable against a fake;
/// only this class needs a device.
abstract interface class DriveAuth {
  /// The scope the app asks for, and the only one.
  ///
  /// `drive.file` grants access to files this app created and nothing else —
  /// it cannot read the user's other documents even in principle. That is both
  /// the honest thing to request and the reason no OAuth verification review is
  /// needed: Google classifies it as non-sensitive.
  static const scope = 'https://www.googleapis.com/auth/drive.file';

  /// Whoever is already signed in, without prompting. Null when nobody is.
  Future<DriveIdentity?> current();

  /// Prompts for sign-in and for the Drive scope. Null if the user backs out.
  Future<DriveIdentity?> signIn();

  Future<void> signOut();
}

/// The real implementation, talking to Google Play services.
class GoogleDriveAuth implements DriveAuth {
  GoogleDriveAuth({required this.serverClientId});

  /// The *web* OAuth client ID, despite this being an Android app.
  ///
  /// Google's model: the Android client is matched implicitly by package name
  /// and signing fingerprint and is never named in code, while the web client
  /// is what identifies the project when tokens are issued. Getting these the
  /// wrong way round is a common and very confusing failure.
  final String serverClientId;

  bool _initialised = false;

  Future<void> _ensureInitialised() async {
    if (_initialised) return;
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _initialised = true;
  }

  @override
  Future<DriveIdentity?> current() async {
    await _ensureInitialised();

    final account = await GoogleSignIn.instance
        .attemptLightweightAuthentication();
    if (account == null) return null;

    // Silent: if the scope was never granted, or was revoked in the Google
    // account settings, this returns null rather than throwing a prompt at a
    // user who did not ask for one.
    final authorization = await account.authorizationClient
        .authorizationForScopes([DriveAuth.scope]);
    if (authorization == null) return null;

    return DriveIdentity(
      email: account.email,
      accessToken: authorization.accessToken,
    );
  }

  @override
  Future<DriveIdentity?> signIn() async {
    await _ensureInitialised();

    try {
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: [DriveAuth.scope],
      );

      // scopeHint is a hint, not a guarantee — on some flows the scope still
      // has to be asked for separately, so this is not redundant.
      final authorization = await account.authorizationClient.authorizeScopes([
        DriveAuth.scope,
      ]);

      return DriveIdentity(
        email: account.email,
        accessToken: authorization.accessToken,
      );
    } on GoogleSignInException catch (e) {
      // Backing out of the account chooser is a normal thing to do, not a
      // failure to report.
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialised();
    await GoogleSignIn.instance.signOut();
  }
}

/// Adds the bearer token to every request.
///
/// `googleapis` wants an authenticated `http.Client`. The package that used to
/// bridge `google_sign_in` to one has not been updated for its 7.x API, and
/// this is all that bridge did.
class DriveHttpClient extends http.BaseClient {
  DriveHttpClient(this._accessToken, this._inner);

  final String _accessToken;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
