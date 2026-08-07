import 'dart:async';

import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/features/ads/ad_pacing.dart';
import 'package:meribiodata/features/ads/consent_gate.dart';
import 'package:meribiodata/features/ads/interstitial_ads.dart';
import 'package:meribiodata/features/premium/billing.dart';
import 'package:meribiodata/features/premium/entitlements.dart';
import 'package:meribiodata/features/premium/premium_products.dart';

/// An interstitial loader that never touches Google's SDK.
///
/// Defaults to *having* an ad, because the interesting tests are the ones where
/// an ad exists and the pacing rules have to decide whether to show it.
class FakeInterstitialLoader implements InterstitialLoader {
  FakeInterstitialLoader({this.hasFill = true, this.delay = Duration.zero});

  /// False models the ordinary case of no fill — a fresh ad unit refuses most
  /// requests for its first day or two.
  bool hasFill;

  /// How long a load takes. Used to drive the timeout path.
  Duration delay;

  int loadCount = 0;
  final List<FakeInterstitialHandle> handles = [];

  @override
  Future<InterstitialHandle?> load(String unitId) async {
    loadCount++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!hasFill) return null;

    final handle = FakeInterstitialHandle();
    handles.add(handle);
    return handle;
  }

  int get shownCount => handles.where((h) => h.shown).length;
}

class FakeInterstitialHandle implements InterstitialHandle {
  bool shown = false;
  bool disposed = false;

  /// Set to make presenting fail the way the real SDK can — an ad that loaded
  /// but cannot be displayed.
  bool throwOnShow = false;

  @override
  Future<void> show() async {
    if (throwOnShow) throw StateError('could not present');
    shown = true;
  }

  @override
  void dispose() => disposed = true;
}

/// Interstitials wired so that nothing can reach the network.
///
/// Widget tests need an [InterstitialAds] because the app requires one, but
/// none of them are about ads — with a refusing [ConsentGate] this never gets
/// as far as asking the loader for anything.
InterstitialAds silentInterstitials(LocalStore store, ConsentGate consent) =>
    InterstitialAds(
      consent: consent,
      pacing: AdPacing(store),
      loader: FakeInterstitialLoader(hasFill: false),
    );

/// Billing that cannot reach Play, so nothing in a widget test can block on it.
///
/// Defaults to "not available", which is also what a device with no Play Store
/// reports — the state the app must survive completely.
class FakeBilling implements Billing {
  FakeBilling({this.available = false, this.ownedPlans = const {}});

  bool available;
  Set<PremiumPlan> ownedPlans;
  PurchaseResult nextResult = PurchaseResult.bought;

  final _controller = StreamController<Set<PremiumPlan>>.broadcast();
  int restoreCalls = 0;
  int buyCalls = 0;

  @override
  Stream<Set<PremiumPlan>> get owned => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<BillingProduct>> products() async => [
    for (final plan in PremiumPlan.values)
      BillingProduct(
        plan: plan,
        // Play's own localised string; the app never builds one.
        price: plan == PremiumPlan.monthly ? 'Rs 299.00' : 'Rs 1,499.00',
        title: plan.name,
        raw: plan,
      ),
  ];

  @override
  Future<PurchaseResult> buy(BillingProduct product) async {
    buyCalls++;
    if (nextResult == PurchaseResult.bought) {
      ownedPlans = {product.plan};
      _controller.add(ownedPlans);
    }
    return nextResult;
  }

  @override
  Future<void> restore() async {
    restoreCalls++;
    if (ownedPlans.isNotEmpty) _controller.add(ownedPlans);
  }

  @override
  void dispose() => unawaited(_controller.close());
}

/// Entitlements that resolve immediately and never reach Play.
Entitlements freeEntitlements(LocalStore store) => Entitlements(
  billing: FakeBilling(),
  store: store,
  verificationWindow: Duration.zero,
);
