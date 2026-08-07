import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:meribiodata/features/premium/premium_products.dart';

/// A product as Play describes it, with the price already localised.
///
/// [price] is a *display string* Play built for the user's country and
/// currency — "Rs 299.00", "$1.19", "₹99.00". It is never assembled in the app.
/// Hard-coding a price would be wrong within a week of the first exchange-rate
/// move, and wrong in every country but one on day one.
class BillingProduct {
  const BillingProduct({
    required this.plan,
    required this.price,
    required this.title,
    required this.raw,
  });

  final PremiumPlan plan;
  final String price;
  final String title;

  /// The platform object, needed to start a purchase.
  final Object raw;
}

/// The outcome of asking Play to charge someone.
enum PurchaseResult {
  /// Play accepted it and the entitlement is now active.
  bought,

  /// The user backed out of Play's sheet. Ordinary, not an error.
  cancelled,

  /// Awaiting a slow payment method. Carrier billing and cash-based methods —
  /// both common in Pakistan — can sit here for minutes or hours. The purchase
  /// completes later through the stream, without the user being on this screen.
  pending,

  /// Play could not complete it. The user is not charged.
  failed,

  /// Play Billing is not usable at all: no Play Store, an old Play services, a
  /// sideloaded build, or an emulator image without Google APIs.
  unavailable,
}

/// Google Play Billing, behind an interface.
///
/// Nothing about billing can run in a unit test: it needs the Play Store app, a
/// signed build installed from a Play track, and a licence-tester account.
/// Everything above this line is testable against a fake; only this class needs
/// a real phone.
abstract interface class Billing {
  /// False when there is no Play Store to talk to. Every caller must cope —
  /// the app is fully usable without Premium, and must stay that way on a
  /// device that cannot buy anything at all.
  Future<bool> isAvailable();

  /// The products Play will actually sell here. A plan missing from this list
  /// is missing from Play Console, or not yet active, or the build is not from
  /// a Play track.
  Future<List<BillingProduct>> products();

  Future<PurchaseResult> buy(BillingProduct product);

  /// Re-delivers everything the account already owns. Required by Play policy:
  /// a user who reinstalls, or signs in on a new phone, must be able to get
  /// their purchase back without paying twice.
  Future<void> restore();

  /// Fires whenever the set of owned plans changes, including purchases that
  /// complete long after the user left the Premium screen.
  Stream<Set<PremiumPlan>> get owned;

  void dispose();
}

/// The real implementation, talking to Play Billing.
class PlayBilling implements Billing {
  PlayBilling({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance {
    _subscription = _store.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) => debugPrint('Purchase stream error: $error'),
    );
  }

  final InAppPurchase _store;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  final _owned = StreamController<Set<PremiumPlan>>.broadcast();

  /// Completes the *foreground* purchase a caller is waiting on. Purchases
  /// arriving on their own — a restore, or a pending payment clearing hours
  /// later — have no completer and simply update [owned].
  Completer<PurchaseResult>? _pending;

  @override
  Stream<Set<PremiumPlan>> get owned => _owned.stream;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _store.isAvailable();
    } on Object catch (error) {
      debugPrint('Play Billing unavailable: $error');
      return false;
    }
  }

  @override
  Future<List<BillingProduct>> products() async {
    try {
      final response = await _store.queryProductDetails(
        PremiumPlan.productIds,
      );
      if (response.error != null) {
        debugPrint('Product query failed: ${response.error}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        // Nearly always a Play Console problem rather than a code one: a typo
        // in the product ID, a product left inactive, or a build the Play Store
        // does not recognise because it was not installed from a track.
        debugPrint('Products not found in Play: ${response.notFoundIDs}');
      }

      final products = <BillingProduct>[];
      for (final details in response.productDetails) {
        final plan = PremiumPlan.forProductId(details.id);
        if (plan == null) continue;
        products.add(
          BillingProduct(
            plan: plan,
            price: details.price,
            title: details.title,
            raw: details,
          ),
        );
      }
      // Monthly first, lifetime second, whatever order Play answered in.
      products.sort((a, b) => a.plan.index.compareTo(b.plan.index));
      return products;
    } on Object catch (error) {
      debugPrint('Product query threw: $error');
      return const [];
    }
  }

  @override
  Future<PurchaseResult> buy(BillingProduct product) async {
    final details = product.raw;
    if (details is! ProductDetails) return PurchaseResult.failed;

    // One at a time. Play shows its own sheet, so a second concurrent attempt
    // could only come from a double tap.
    if (_pending != null && !_pending!.isCompleted) {
      return PurchaseResult.pending;
    }

    final completer = Completer<PurchaseResult>();
    _pending = completer;

    try {
      // Non-consumable for both: a subscription is bought this way too on
      // Android, and neither product is ever consumed and re-bought.
      final started = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      if (!started) {
        _pending = null;
        return PurchaseResult.failed;
      }
    } on Object catch (error) {
      debugPrint('Could not start purchase: $error');
      _pending = null;
      return PurchaseResult.failed;
    }

    return completer.future;
  }

  @override
  Future<void> restore() async {
    try {
      await _store.restorePurchases();
    } on Object catch (error) {
      debugPrint('Restore failed: $error');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    final active = <PremiumPlan>{};
    var result = PurchaseResult.failed;

    for (final purchase in purchases) {
      final plan = PremiumPlan.forProductId(purchase.productID);

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (plan != null) active.add(plan);
          result = PurchaseResult.bought;
        case PurchaseStatus.pending:
          result = PurchaseResult.pending;
        case PurchaseStatus.canceled:
          result = PurchaseResult.cancelled;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${purchase.error}');
          result = PurchaseResult.failed;
      }

      // Mandatory. An unacknowledged purchase is automatically refunded by
      // Google after three days, so skipping this quietly hands the money back
      // and leaves the user entitled to nothing.
      if (purchase.pendingCompletePurchase) {
        try {
          await _store.completePurchase(purchase);
        } on Object catch (error) {
          debugPrint('Could not complete purchase: $error');
        }
      }
    }

    if (active.isNotEmpty) _owned.add(active);

    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(result);
      if (result != PurchaseResult.pending) _pending = null;
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_owned.close());
  }
}
