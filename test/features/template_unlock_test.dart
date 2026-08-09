import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/domain/render/templates.dart';
import 'package:meribiodata/features/ads/rewarded_ads.dart';
import 'package:meribiodata/features/templates/template_unlocks.dart';

import '../support/fake_ads.dart';
import '../support/fake_consent.dart';
import '../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late DateTime clock;

  final start = DateTime(2026, 8, 8, 9);

  /// Whichever template is locked today rather than a hardcoded id, so
  /// re-locking a different design does not quietly turn these into tests of
  /// a free template that always pass.
  final lockedTemplate = Templates.all.firstWhere((t) => t.isLocked);
  final locked = lockedTemplate.id;

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    clock = start;
  });

  TemplateUnlocks unlocks() => TemplateUnlocks(store, now: () => clock);

  group('what one ad buys', () {
    test('nothing is unlocked to begin with', () async {
      final u = unlocks();
      await u.load();

      expect(u.isUnlocked(locked), isFalse);
      expect(u.remainingFor(locked), isNull);
    });

    test('exactly 24 hours, and only for that template', () async {
      final u = unlocks();
      await u.load();
      await u.grant(locked);

      expect(u.isUnlocked(locked), isTrue);
      // The owner's choice over my recommendation: one ad buys one template,
      // not the set. Asserted against another *locked* template, since a free
      // one would pass this trivially.
      final otherLocked = Templates.all
          .where((t) => t.isLocked && t.id != locked)
          .first;
      expect(u.isUnlocked(otherLocked.id), isFalse);

      clock = start.add(const Duration(hours: 23, minutes: 59));
      expect(u.isUnlocked(locked), isTrue);

      clock = start.add(const Duration(hours: 24, minutes: 1));
      expect(u.isUnlocked(locked), isFalse);
    });

    test('survives a restart', () async {
      final first = unlocks();
      await first.load();
      await first.grant(locked);

      clock = start.add(const Duration(hours: 3));
      final second = unlocks();
      await second.load();

      expect(second.isUnlocked(locked), isTrue);
      expect(second.remainingFor(locked)!.inHours, 21);
    });

    test('a wound-back clock is never told it has 168 hours', () async {
      final u = unlocks();
      await u.load();
      await u.grant(locked);

      // Winding the clock back does keep the unlock alive longer in real time —
      // the expiry is an absolute instant. That is accepted (see the class
      // doc), but what must not happen is the UI advertising the fact.
      clock = start.subtract(const Duration(days: 5));
      expect(u.isUnlocked(locked), isTrue);
      expect(u.remainingFor(locked), TemplateUnlocks.duration);

      clock = start.add(const Duration(days: 2));
      expect(u.isUnlocked(locked), isFalse);
    });

    test('watching again after expiry starts a fresh 24 hours', () async {
      final u = unlocks();
      await u.load();
      await u.grant(locked);

      clock = start.add(const Duration(days: 2));
      expect(u.isUnlocked(locked), isFalse);

      await u.grant(locked);
      expect(u.isUnlocked(locked), isTrue);
      expect(u.remainingFor(locked), TemplateUnlocks.duration);
    });
  });

  group('who may use a template', () {
    test('free templates need nothing', () async {
      final u = unlocks();
      await u.load();

      for (final template in Templates.free) {
        expect(
          canUseTemplate(template, isPremium: false, unlocks: u),
          isTrue,
          reason: '${template.id} is free and must never be gated',
        );
      }
      // An app whose core action needs an ad is a different, worse app.
      expect(Templates.free, isNotEmpty);
      expect(
        Templates.free.map((t) => t.id),
        contains(Templates.defaultId),
        reason: 'the default template must always be reachable',
      );
    });

    test('Premium opens everything, with no ad and no expiry', () async {
      final u = unlocks();
      await u.load();

      for (final template in Templates.all) {
        expect(canUseTemplate(template, isPremium: true, unlocks: u), isTrue);
      }

      // Still true a year later — Premium does not run out the way an ad does.
      clock = start.add(const Duration(days: 365));
      expect(
        canUseTemplate(lockedTemplate, isPremium: true, unlocks: u),
        isTrue,
      );
    });

    test('an ad unlock expires where Premium would not', () async {
      final u = unlocks();
      await u.load();
      await u.grant(locked);

      expect(
        canUseTemplate(lockedTemplate, isPremium: false, unlocks: u),
        isTrue,
      );

      clock = start.add(const Duration(days: 2));
      // The strict rule: it locks everywhere, including for a biodata already
      // using it. The export screen enforces the same check.
      expect(
        canUseTemplate(lockedTemplate, isPremium: false, unlocks: u),
        isFalse,
      );
    });
  });

  group('the rewarded ad', () {
    test('grants nothing when the user closes it early', () async {
      final loader = FakeRewardedLoader()..earnsReward = false;
      final ads = RewardedAds(
        consent: await resolvedGateWithAds(),
        loader: loader,
      );

      expect(await ads.show(), RewardOutcome.dismissed);
    });

    test('reports earned only when watched to the end', () async {
      final ads = RewardedAds(
        consent: await resolvedGateWithAds(),
        loader: FakeRewardedLoader(),
      );

      expect(await ads.show(), RewardOutcome.earned);
    });

    test('is unavailable without consent, and never requests one', () async {
      final loader = FakeRewardedLoader();
      final ads = RewardedAds(
        consent: await resolvedGateWithoutAds(),
        loader: loader,
      );

      expect(ads.isAvailable, isFalse);
      expect(await ads.show(), RewardOutcome.unavailable);
      expect(loader.loadCount, 0);
    });

    test('no fill is reported rather than silently granting', () async {
      final ads = RewardedAds(
        consent: await resolvedGateWithAds(),
        loader: FakeRewardedLoader()..hasFill = false,
      );

      // The failure that would matter is this returning `earned` — a reward
      // for an ad that never played.
      expect(await ads.show(), RewardOutcome.unavailable);
    });
  });
}
