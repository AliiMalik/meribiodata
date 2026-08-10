/// The two things a user can buy, and what buying either one grants.
///
/// Both grant exactly the same thing. The only difference is how long it lasts
/// and how it is billed — there is deliberately no feature that one has and the
/// other does not, because a matrix of tiers at this price is confusion for no
/// extra revenue.
enum PremiumPlan {
  /// A Play *subscription*. Renews until cancelled; the entitlement ends with
  /// it.
  monthly('premium_monthly'),

  /// A Play *in-app product*, bought once and owned for good.
  ///
  /// A different product type in Play Console, on a different screen, which is
  /// the usual reason one of the two is missing at runtime.
  lifetime('premium_lifetime');

  const PremiumPlan(this.productId);

  /// Must match the product ID in Play Console character for character. A
  /// mismatch does not fail loudly — the product simply comes back in
  /// `notFoundIDs` and the offer never appears.
  final String productId;

  /// Deep link to Play's own subscription management, for this product.
  ///
  /// Play policy requires a route to cancel or change a subscription from
  /// inside the app, and it must go to Play rather than to anything we build:
  /// Google took the money, so Google shows the terms and handles the refund.
  /// Meaningless for [lifetime], which has nothing to manage.
  String get manageUrl =>
      'https://play.google.com/store/account/subscriptions'
      '?sku=$productId&package=$_packageName';

  static const _packageName = 'safarnamastudios.meribiodata.app';

  static const productIds = <String>{
    'premium_monthly',
    'premium_lifetime',
  };

  static PremiumPlan? forProductId(String id) {
    for (final plan in values) {
      if (plan.productId == id) return plan;
    }
    return null;
  }
}

/// What Premium removes.
///
/// Written down as a list because it is also the promise made on the Premium
/// screen, and the two must not drift apart.
abstract final class PremiumBenefits {
  /// No banner on Home or the editor, and no interstitial before the editor.
  static const removesAds = true;

  /// Exports carry no watermark band.
  static const removesWatermark = true;
}
