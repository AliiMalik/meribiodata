import 'dart:typed_data';

import 'package:meribiodata/features/sync/drive_auth.dart';
import 'package:meribiodata/features/sync/drive_client.dart';
import 'package:meribiodata/features/sync/sync_service.dart';

/// Stands in for Google sign-in.
///
/// The real one needs an activity, a Google account and a network, so nothing
/// above [DriveAuth] could be tested at all without this. Everything it does is
/// return values and count calls.
class FakeDriveAuth implements DriveAuth {
  FakeDriveAuth({this.signedInAs, this.refuseSignIn = false});

  /// Who is already signed in when the test starts. Null for a fresh phone.
  String? signedInAs;

  /// Simulates the user backing out of the account chooser.
  bool refuseSignIn;

  int signInCalls = 0;
  int signOutCalls = 0;

  DriveIdentity? _identity(String? email) => email == null
      ? null
      : DriveIdentity(email: email, accessToken: 'fake-token-for-$email');

  @override
  Future<DriveIdentity?> current() async => _identity(signedInAs);

  @override
  Future<DriveIdentity?> signIn() async {
    signInCalls++;
    if (refuseSignIn) return null;
    signedInAs ??= 'someone@example.com';
    return _identity(signedInAs);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedInAs = null;
  }
}

/// An in-memory stand-in for the platform keystore.
class FakeSyncPasswordStore implements SyncPasswordStore {
  FakeSyncPasswordStore([this._value]);

  String? _value;

  @override
  Future<String?> read() async => _value;

  @override
  Future<void> write(String password) async => _value = password;

  @override
  Future<void> clear() async => _value = null;
}

/// A Drive that lives in a variable.
///
/// Holds the uploaded bytes verbatim, which is what lets a test assert that the
/// thing which reached "Drive" is genuinely unreadable without the password.
class FakeDrive {
  Uint8List? contents;
  DateTime modifiedAt = DateTime.utc(2026, 8, 6, 12);

  int uploads = 0;
  int downloads = 0;

  /// Set to make the next call fail, standing in for no signal.
  bool offline = false;

  DriveClient clientFor(DriveIdentity identity) =>
      _FakeDriveClient(this, identity);
}

class _FakeDriveClient implements DriveClient {
  _FakeDriveClient(this._drive, this._identity);

  final FakeDrive _drive;
  final DriveIdentity _identity;

  void _check() {
    if (_drive.offline) throw Exception('no network');
    if (_identity.accessToken.isEmpty) throw Exception('no token');
  }

  @override
  Future<RemoteBackup?> find() async {
    _check();
    final bytes = _drive.contents;
    if (bytes == null) return null;
    return RemoteBackup(
      fileId: 'fake-file',
      modifiedAt: _drive.modifiedAt,
      bytes: bytes.length,
    );
  }

  @override
  Future<RemoteBackup> upload(Uint8List data) async {
    _check();
    _drive.uploads++;
    _drive.contents = data;
    _drive.modifiedAt = _drive.modifiedAt.add(const Duration(minutes: 1));
    return RemoteBackup(
      fileId: 'fake-file',
      modifiedAt: _drive.modifiedAt,
      bytes: data.length,
    );
  }

  @override
  Future<Uint8List> download(String fileId) async {
    _check();
    _drive.downloads++;
    final bytes = _drive.contents;
    if (bytes == null) throw Exception('nothing there');
    return bytes;
  }
}
