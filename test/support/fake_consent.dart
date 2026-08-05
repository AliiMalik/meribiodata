import 'package:meribiodata/features/ads/consent_gate.dart';

/// A [ConsentPlatform] that never touches the UMP SDK.
///
/// Every test in this suite runs with ads off unless it says otherwise — a test
/// that accidentally initialised the real Mobile Ads SDK would either hang or
/// make a network call, and neither belongs in a unit test.
class FakeConsentPlatform implements ConsentPlatform {
  FakeConsentPlatform({
    this.permitted = false,
    this.throwOnRequest = false,
    this.throwOnQuery = false,
  });

  final bool permitted;
  final bool throwOnRequest;
  final bool throwOnQuery;

  int requestCount = 0;
  int queryCount = 0;

  @override
  Future<void> requestConsent() async {
    requestCount++;
    if (throwOnRequest) throw StateError('consent form unavailable');
  }

  @override
  Future<bool> canRequestAds() async {
    queryCount++;
    if (throwOnQuery) throw StateError('consent status unavailable');
    return permitted;
  }
}

/// A gate that is resolved and refusing ads — the default for widget tests.
Future<ConsentGate> resolvedGateWithoutAds() async {
  final gate = ConsentGate(
    platform: FakeConsentPlatform(),
    initialiseAds: () async {},
  );
  await gate.resolve();
  return gate;
}
