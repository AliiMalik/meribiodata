import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Where the consent flow got to.
enum ConsentStatus {
  /// Not asked yet.
  unknown,

  /// Consent resolved and ads may be requested.
  canRequestAds,

  /// Resolved, but the user declined enough that ads must not be requested.
  cannotRequestAds,

  /// The consent SDK itself failed — offline, no Google Play services, a
  /// misconfigured AdMob app. Treated as "no ads", never as "ads anyway".
  failed,
}

/// Gates the Mobile Ads SDK behind UMP consent.
///
/// §8 requires consent to be **requested before ad initialisation**, because
/// the app is listed globally and EEA users need it. The ordering is the whole
/// point: initialising the SDK first and asking afterwards is what regulators
/// object to, and it is an easy mistake to make because the ads still work.
///
/// Every failure path lands on "do not show ads". An app that shows ads because
/// the consent check errored is worse than an app that shows none.
class ConsentGate extends ChangeNotifier {
  ConsentGate({
    @visibleForTesting ConsentPlatform? platform,
    @visibleForTesting Future<void> Function()? initialiseAds,
  }) : _platform = platform ?? const _UmpConsentPlatform(),
       _initialiseAds = initialiseAds ?? _defaultInitialiseAds;

  final ConsentPlatform _platform;
  final Future<void> Function() _initialiseAds;

  ConsentStatus _status = ConsentStatus.unknown;
  bool _adsInitialised = false;

  ConsentStatus get status => _status;

  /// The single question the rest of the app asks. Anything other than a
  /// resolved yes is a no.
  bool get canShowAds =>
      _status == ConsentStatus.canRequestAds && _adsInitialised;

  /// Runs the consent flow, then initialises ads only if it is permitted.
  ///
  /// Safe to call more than once; the SDK is initialised at most once.
  Future<void> resolve() async {
    try {
      await _platform.requestConsent();
      final permitted = await _platform.canRequestAds();
      _status = permitted
          ? ConsentStatus.canRequestAds
          : ConsentStatus.cannotRequestAds;
    } on Object catch (error, stack) {
      // Offline, no Play services, or a consent form that would not load. The
      // app must keep working with no ads at all (NFR-3).
      debugPrint('Consent flow failed, disabling ads: $error\n$stack');
      _status = ConsentStatus.failed;
    }

    if (_status == ConsentStatus.canRequestAds && !_adsInitialised) {
      try {
        await _initialiseAds();
        _adsInitialised = true;
      } on Object catch (error) {
        debugPrint('Ads SDK failed to initialise: $error');
        _status = ConsentStatus.failed;
      }
    }

    notifyListeners();
  }

  static Future<void> _defaultInitialiseAds() async {
    await MobileAds.instance.initialize();
  }
}

/// The consent SDK, behind an interface so the gate's ordering and failure
/// handling can be tested without a device.
abstract interface class ConsentPlatform {
  Future<void> requestConsent();

  Future<bool> canRequestAds();
}

class _UmpConsentPlatform implements ConsentPlatform {
  const _UmpConsentPlatform();

  @override
  Future<void> requestConsent() {
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          // Shows the form only where one is required — in most of the world
          // this is a no-op and the user sees nothing.
          await ConsentForm.loadAndShowConsentFormIfRequired((error) {
            if (error != null) {
              debugPrint('Consent form error: ${error.message}');
            }
            if (!completer.isCompleted) completer.complete();
          });
        } on Object catch (error) {
          if (!completer.isCompleted) completer.completeError(error);
        }
      },
      (error) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Consent info update failed: ${error.message}'),
          );
        }
      },
    );

    return completer.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();
}
