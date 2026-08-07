import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/features/ads/ad_config.dart';
import 'package:meribiodata/features/ads/ad_pacing.dart';
import 'package:meribiodata/features/ads/interstitial_ads.dart';
import 'package:meribiodata/features/premium/billing.dart';
import 'package:meribiodata/features/premium/entitlements.dart';
import 'package:meribiodata/features/premium/premium_products.dart';
import 'package:meribiodata/features/premium/premium_prompts.dart';

import '../support/fake_ads.dart';
import '../support/fake_consent.dart';
import '../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late FakeBilling billing;

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    billing = FakeBilling(available: true);
  });

  Entitlements build() => Entitlements(
    billing: billing,
    store: store,
    verificationWindow: const Duration(milliseconds: 30),
  );

  group('what the app believes', () {
    test('nobody is premium until Play says so', () async {
      final entitlements = build();
      await entitlements.load();

      expect(entitlements.isPremium, isFalse);
      expect(entitlements.plan, isNull);
    });

    test('buying grants it immediately', () async {
      final entitlements = build();
      await entitlements.load();

      final offers = await entitlements.offers();
      final lifetime = offers.firstWhere(
        (o) => o.plan == PremiumPlan.lifetime,
      );
      final result = await entitlements.buy(lifetime);

      expect(result, PurchaseResult.bought);
      expect(entitlements.isPremium, isTrue);
      expect(entitlements.plan, PremiumPlan.lifetime);
    });

    test('it survives a restart without asking Play again', () async {
      final first = build();
      await first.load();
      final offers = await first.offers();
      await first.buy(offers.first);
      expect(first.isPremium, isTrue);

      // A new process. Play is unreachable — a plane, a dead connection, a
      // phone with no Play Store at all.
      billing.available = false;
      final second = build();
      await second.load();

      // The cache is authoritative when Play cannot be asked. Anything else
      // means someone who paid this morning sees ads on the underground.
      expect(second.isPremium, isTrue);
    });

    test('a lapsed subscription is noticed once Play can be asked', () async {
      final first = build();
      await first.load();
      final monthly = (await first.offers()).firstWhere(
        (o) => o.plan == PremiumPlan.monthly,
      );
      await first.buy(monthly);
      expect(first.isPremium, isTrue);

      // Cancelled, refunded, or the card expired: Play now reports nothing.
      billing.ownedPlans = const {};
      final second = build();
      await second.load();

      expect(second.isPremium, isFalse);
    });

    test('an unreachable Play never revokes anything', () async {
      final first = build();
      await first.load();
      await first.buy((await first.offers()).first);

      billing
        ..ownedPlans = const {}
        ..available = false;
      final second = build();
      await second.load();

      // Play said nothing because it could not be reached, which is not the
      // same as saying "you own nothing". Revoking here would be the worst
      // possible bug in this file.
      expect(second.isPremium, isTrue);
    });

    test('restoring is how a reinstalled app gets it back', () async {
      billing.ownedPlans = {PremiumPlan.lifetime};

      final entitlements = build();
      await entitlements.load();

      expect(billing.restoreCalls, greaterThan(0));
      expect(entitlements.isPremium, isTrue);
      expect(entitlements.plan, PremiumPlan.lifetime);
    });

    test('lifetime wins the label over a monthly held at once', () async {
      billing.ownedPlans = {PremiumPlan.monthly, PremiumPlan.lifetime};

      final entitlements = build();
      await entitlements.load();

      expect(entitlements.plan, PremiumPlan.lifetime);
    });
  });

  group('a device that cannot buy anything still works', () {
    test('no Play Store means no offers and no crash', () async {
      billing.available = false;
      final entitlements = build();
      await entitlements.load();

      expect(entitlements.isPremium, isFalse);

      final offers = await entitlements.offers();
      final product = offers.first;
      // Refused before Play is ever asked, so the user gets a clear message
      // rather than a dialog that never appears.
      expect(await entitlements.buy(product), PurchaseResult.unavailable);
      expect(billing.buyCalls, 0);
    });
  });

  group('Premium switches the ads off', () {
    test('no interstitial, and no request made on their behalf', () async {
      final entitlements = build();
      await entitlements.load();
      await entitlements.buy((await entitlements.offers()).first);
      expect(entitlements.isPremium, isTrue);

      final loader = FakeInterstitialLoader();
      final ads = InterstitialAds(
        consent: await resolvedGateWithAds(),
        pacing: AdPacing(store),
        isPremium: () => entitlements.isPremium,
        loader: loader,
      );

      // Well past the free-creates allowance, so pacing is not what is
      // stopping this.
      for (var i = 0; i < AdConfig.interstitialFreeCreates + 3; i++) {
        await ads.onCreateBiodata();
      }

      expect(loader.shownCount, 0);
      // Not merely unshown: a paying user's device makes no ad request at all.
      expect(loader.loadCount, 0);
    });

    test('the ads come back if the subscription lapses', () async {
      final entitlements = build();
      await entitlements.load();
      await entitlements.buy(
        (await entitlements.offers()).firstWhere(
          (o) => o.plan == PremiumPlan.monthly,
        ),
      );

      final loader = FakeInterstitialLoader();
      final ads = InterstitialAds(
        consent: await resolvedGateWithAds(),
        pacing: AdPacing(store),
        isPremium: () => entitlements.isPremium,
        loader: loader,
      );

      billing.ownedPlans = const {};
      await entitlements.refresh();
      expect(entitlements.isPremium, isFalse);

      for (var i = 0; i < AdConfig.interstitialFreeCreates + 1; i++) {
        await ads.onCreateBiodata();
      }

      expect(loader.shownCount, 1);
    });
  });

  group('the product catalogue', () {
    test('IDs match what has to be typed into Play Console', () {
      // A mismatch does not throw — the product silently never loads — so this
      // is the only place it can be caught.
      expect(PremiumPlan.monthly.productId, 'premium_monthly');
      expect(PremiumPlan.lifetime.productId, 'premium_lifetime');
      expect(
        PremiumPlan.productIds,
        {for (final plan in PremiumPlan.values) plan.productId},
      );
    });

    test('every product ID maps back to its plan', () {
      for (final plan in PremiumPlan.values) {
        expect(PremiumPlan.forProductId(plan.productId), plan);
      }
      expect(PremiumPlan.forProductId('something_else'), isNull);
    });
  });

  group('how often Premium is allowed to ask', () {
    late DateTime clock;
    final start = DateTime(2026, 8, 8, 9);

    PremiumPrompts prompts() => PremiumPrompts(store, now: () => clock);

    setUp(() => clock = start);

    test('says nothing on the first run', () async {
      final p = prompts();
      await p.load();

      // The last onboarding panel has just made this pitch. Following it with
      // the full screen is how an app teaches people to dismiss things unread.
      expect(p.canPromptAtLaunch, isFalse);
      expect(p.showCard, isTrue);
    });

    test('asks again a week later, not before', () async {
      await prompts().load();

      clock = start.add(
        PremiumPrompts.promptInterval - const Duration(hours: 1),
      );
      final tooSoon = prompts();
      await tooSoon.load();
      expect(tooSoon.canPromptAtLaunch, isFalse);

      clock = start.add(
        PremiumPrompts.promptInterval + const Duration(hours: 1),
      );
      final due = prompts();
      await due.load();
      expect(due.canPromptAtLaunch, isTrue);
    });

    test('only once per app run, however long it stays open', () async {
      clock = start;
      await prompts().load();

      clock = start.add(const Duration(days: 30));
      final p = prompts();
      await p.load();
      expect(p.canPromptAtLaunch, isTrue);

      await p.recordPrompt();
      // Same object, same session: a second navigation back to Home must not
      // reopen it.
      expect(p.canPromptAtLaunch, isFalse);
    });

    test('a dismissed card stays dismissed across restarts', () async {
      final first = prompts();
      await first.load();
      await first.dismissCard();
      expect(first.showCard, isFalse);

      final second = prompts();
      await second.load();
      expect(second.showCard, isFalse);
    });

    test('a clock moved backwards does not unlock an early prompt', () async {
      clock = start;
      await prompts().load();

      clock = start.subtract(const Duration(days: 30));
      final p = prompts();
      await p.load();

      expect(p.canPromptAtLaunch, isFalse);
    });
  });
}
