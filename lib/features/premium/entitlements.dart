import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/features/premium/billing.dart';
import 'package:meribiodata/features/premium/premium_products.dart';

/// Whether this user has paid, and the only question the rest of the app asks.
///
/// Ads and the export watermark both read [isPremium] and nothing else. Neither
/// knows that Play Billing exists.
///
/// **There is no server-side receipt check, and that is deliberate.** Verifying
/// a purchase properly means sending Play's receipt to a backend the developer
/// controls — and this app has no backend, on purpose (NFR-1). A rooted phone
/// running a billing emulator can therefore claim Premium it never paid for.
/// For an unlock that removes ads and a watermark at this price, that is the
/// better trade: the alternative is standing up a server, which would undo the
/// promise the whole app is built on to protect a rupee or two.
class Entitlements extends ChangeNotifier {
  Entitlements({
    required Billing billing,
    required LocalStore store,
    @visibleForTesting Duration? verificationWindow,
  }) : // A named parameter cannot be written `this._billing` — named
       // parameters may not begin with an underscore — so the lint's suggested
       // fix does not compile. Same below.
       // ignore: prefer_initializing_formals
       _billing = billing,
       // Same false positive.
       // ignore: prefer_initializing_formals
       _store = store,
       _verificationWindow = verificationWindow ?? const Duration(seconds: 6) {
    _ownership = _billing.owned.listen(_onOwned);
  }

  static const _documentId = 'premium';
  static const _keyPremium = 'premium';
  static const _keyPlan = 'plan';

  final Billing _billing;
  final LocalStore _store;
  final Duration _verificationWindow;
  late final StreamSubscription<Set<PremiumPlan>> _ownership;

  bool _premium = false;
  PremiumPlan? _plan;
  bool _sawOwnership = false;
  bool _checking = false;

  /// The one question. False until proven otherwise.
  bool get isPremium => _premium;

  /// Which purchase is responsible, for display on the Premium screen. Null
  /// when [isPremium] is false, or when a cached entitlement outlived the
  /// record of which plan bought it.
  PremiumPlan? get plan => _plan;

  /// True while Play is being consulted, so the UI can avoid flashing an
  /// upsell at somebody who has already paid.
  bool get isChecking => _checking;

  /// Reads the cached answer, then re-checks with Play.
  ///
  /// The cache is read first and trusted immediately: a paying user on a train
  /// with no signal must not see ads, and waiting for Play before deciding
  /// would show them ads for as long as the check takes.
  Future<void> load() async {
    await _readCache();
    notifyListeners();
    await refresh();
  }

  /// Asks Play what this account currently owns.
  ///
  /// This is also how a *lapsed subscription* is noticed. The rule is
  /// deliberately asymmetric:
  ///
  /// * Play says "owned" → Premium, cached.
  /// * Play says nothing, and Play was reachable → not Premium, cache cleared.
  /// * Play was **not** reachable → the cached answer stands, untouched.
  ///
  /// Erring toward keeping the entitlement is the right way round. Wrongly
  /// granting Premium for a while costs an ad impression; wrongly revoking it
  /// means someone who paid this morning is served ads on the underground, and
  /// writes the review that says so.
  Future<void> refresh() async {
    if (_checking) return;
    _checking = true;
    notifyListeners();

    try {
      if (!await _billing.isAvailable()) {
        // No Play Store, or no connection to it. Say nothing and keep whatever
        // the cache holds.
        return;
      }

      _sawOwnership = false;
      await _billing.restore();
      // Restoring answers through the stream, and silence is how "you own
      // nothing" arrives — there is no explicit empty response to wait for.
      await Future<void>.delayed(_verificationWindow);

      if (!_sawOwnership && _premium) {
        _premium = false;
        _plan = null;
        await _writeCache();
      }
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  Future<List<BillingProduct>> offers() => _billing.products();

  Future<PurchaseResult> buy(BillingProduct product) async {
    if (!await _billing.isAvailable()) return PurchaseResult.unavailable;
    return _billing.buy(product);
  }

  /// Play policy requires a way to get a purchase back after a reinstall.
  Future<void> restore() => refresh();

  void _onOwned(Set<PremiumPlan> owned) {
    if (owned.isEmpty) return;
    _sawOwnership = true;

    // Lifetime wins the label when somebody holds both — it is the one that
    // does not expire.
    final plan = owned.contains(PremiumPlan.lifetime)
        ? PremiumPlan.lifetime
        : owned.first;

    final changed = !_premium || _plan != plan;
    _premium = true;
    _plan = plan;
    if (changed) {
      unawaited(_writeCache());
      notifyListeners();
    }
  }

  Future<void> _readCache() async {
    try {
      final values =
          await _store.read(Collections.preferences, _documentId) ?? const {};
      _premium = values[_keyPremium] as bool? ?? false;
      if (values[_keyPlan] case final String name) {
        _plan = PremiumPlan.values.where((p) => p.name == name).firstOrNull;
      }
    } on Object catch (error) {
      // A user who cannot be identified as paying sees the free app, which
      // works completely. Failing the other way would give Premium away on any
      // storage hiccup.
      debugPrint('Entitlement cache unreadable: $error');
      _premium = false;
      _plan = null;
    }
  }

  Future<void> _writeCache() async {
    try {
      await _store.put(Collections.preferences, _documentId, {
        _keyPremium: _premium,
        if (_plan case final PremiumPlan plan) _keyPlan: plan.name,
      });
    } on Object catch (error) {
      debugPrint('Entitlement cache not saved: $error');
    }
  }

  @override
  void dispose() {
    unawaited(_ownership.cancel());
    super.dispose();
  }
}
