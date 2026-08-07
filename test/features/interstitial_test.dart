import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/features/ads/ad_config.dart';
import 'package:meribiodata/features/ads/ad_pacing.dart';
import 'package:meribiodata/features/ads/consent_gate.dart';
import 'package:meribiodata/features/ads/interstitial_ads.dart';

import '../support/fake_ads.dart';
import '../support/fake_consent.dart';
import '../support/in_memory_local_store.dart';

void main() {
  late InMemoryLocalStore store;
  late FakeInterstitialLoader loader;
  late ConsentGate adsOn;
  late DateTime clock;

  /// A fixed starting point rather than DateTime.now(), so the daily-cap tests
  /// cannot fail depending on what time of day CI happens to run.
  final start = DateTime(2026, 8, 7, 10);

  setUp(() async {
    store = InMemoryLocalStore();
    await store.init();
    loader = FakeInterstitialLoader();
    adsOn = await resolvedGateWithAds();
    clock = start;
  });

  InterstitialAds build({ConsentGate? consent}) => InterstitialAds(
    consent: consent ?? adsOn,
    pacing: AdPacing(store, now: () => clock),
    loader: loader,
  );

  /// Walks through [count] creates, leaving enough time between them to clear
  /// the interval so that only the other limits are under test.
  ///
  /// The clock advances *before* each create rather than after, so it finishes
  /// sitting at the moment of the last one. Advancing afterwards would silently
  /// hand every following assertion a fresh interval.
  Future<void> createTimes(InterstitialAds ads, int count) async {
    for (var i = 0; i < count; i++) {
      if (i > 0) clock = clock.add(AdConfig.interstitialInterval * 2);
      await ads.onCreateBiodata();
    }
  }

  group('the ad never gets in the way', () {
    test('the first creates are never interrupted', () async {
      final ads = build();

      await createTimes(ads, AdConfig.interstitialFreeCreates);

      // Someone deciding whether this app is worth their time must reach the
      // form without a full-screen ad in front of it.
      expect(loader.shownCount, 0);
    });

    test('an ad appears once the free creates are used up', () async {
      final ads = build();

      await createTimes(ads, AdConfig.interstitialFreeCreates + 1);

      expect(loader.shownCount, 1);
    });

    test('no fill still opens the editor', () async {
      loader.hasFill = false;
      final ads = build();

      await createTimes(ads, AdConfig.interstitialFreeCreates + 1);

      // The point is that this returned at all. An exception here would reach
      // _create() and lose the user their tap.
      expect(loader.shownCount, 0);
      expect(loader.loadCount, greaterThan(0));
    });

    test('a slow ad is abandoned rather than waited on', () async {
      loader.delay = AdConfig.interstitialLoadTimeout * 4;
      final ads = build();

      final watch = Stopwatch()..start();
      await createTimes(ads, AdConfig.interstitialFreeCreates + 1);
      watch.stop();

      expect(loader.shownCount, 0);
      // Generous, because the assertion is "gave up near the timeout", not
      // "gave up in exactly 1500ms".
      expect(watch.elapsed, lessThan(AdConfig.interstitialLoadTimeout * 3));
    });

    test('an ad that cannot be presented is swallowed', () async {
      final ads = build();
      await createTimes(ads, AdConfig.interstitialFreeCreates);

      // Preloaded during those creates, so this is the handle the next one will
      // reach for.
      final ready = loader.handles.single..throwOnShow = true;

      clock = clock.add(AdConfig.interstitialInterval * 2);
      await ads.onCreateBiodata();

      expect(ready.shown, isFalse);
      expect(ready.disposed, isTrue);
    });

    test('nothing is requested at all without consent', () async {
      final ads = build(consent: await resolvedGateWithoutAds());

      await createTimes(ads, AdConfig.interstitialFreeCreates + 3);

      // Not merely "no ad shown": no request may leave the device before the
      // consent flow has permitted one (§8).
      expect(loader.loadCount, 0);
      expect(loader.shownCount, 0);
    });
  });

  group('pacing limits', () {
    test('a burst of creates yields one ad, not one each', () async {
      final ads = build();
      await createTimes(ads, AdConfig.interstitialFreeCreates + 1);
      expect(loader.shownCount, 1);

      // Three more, all inside the interval.
      for (var i = 0; i < 3; i++) {
        clock = clock.add(const Duration(seconds: 5));
        await ads.onCreateBiodata();
      }

      expect(loader.shownCount, 1);
    });

    test('the daily cap holds even with hours between creates', () async {
      final ads = build();

      // Far more creates than the cap, each an hour apart so the interval is
      // never the thing stopping them.
      for (var i = 0; i < AdConfig.interstitialDailyCap + 5; i++) {
        await ads.onCreateBiodata();
        clock = clock.add(const Duration(hours: 1));
        // Still the same day: the loop is short enough not to roll over.
        expect(clock.day, start.day);
      }

      expect(loader.shownCount, AdConfig.interstitialDailyCap);
    });

    test('the cap resets the next day', () async {
      final ads = build();
      for (var i = 0; i < AdConfig.interstitialDailyCap + 2; i++) {
        await ads.onCreateBiodata();
        clock = clock.add(const Duration(minutes: 30));
      }
      expect(loader.shownCount, AdConfig.interstitialDailyCap);

      clock = start.add(const Duration(days: 1));
      await ads.onCreateBiodata();

      expect(loader.shownCount, AdConfig.interstitialDailyCap + 1);
    });

    test('a double-tapped button does not stack two ads', () async {
      final ads = build();
      await createTimes(ads, AdConfig.interstitialFreeCreates);
      clock = clock.add(AdConfig.interstitialInterval * 2);

      // Both taps land before the first has recorded anything, so the pacing
      // state cannot be what stops the second one.
      await Future.wait([ads.onCreateBiodata(), ads.onCreateBiodata()]);

      expect(loader.shownCount, 1);
    });

    test('a clock moved backwards does not unlock an extra ad', () async {
      final ads = build();
      await createTimes(ads, AdConfig.interstitialFreeCreates + 1);
      expect(loader.shownCount, 1);

      // A timezone change, or a user setting the date. Treated as "too soon":
      // the alternative is a trivial way to bypass the interval.
      clock = clock.subtract(const Duration(days: 2));
      await ads.onCreateBiodata();

      expect(loader.shownCount, 1);
    });
  });

  group('the count survives a restart', () {
    test('creates made before consent still use up the allowance', () async {
      // Ads off — the app has not resolved consent yet, or the user declined
      // and later changed their mind.
      final offline = build(consent: await resolvedGateWithoutAds());
      await createTimes(offline, AdConfig.interstitialFreeCreates);
      expect(loader.loadCount, 0);

      // A fresh app process, same storage, ads now permitted.
      final ads = build();
      await ads.onCreateBiodata();

      // The free creates were spent while ads were off. Reloading must not hand
      // them back — otherwise killing the app resets the allowance forever.
      expect(loader.shownCount, 1);
    });

    test('the daily count is not reset by a restart', () async {
      final first = build();
      for (var i = 0; i < AdConfig.interstitialDailyCap + 2; i++) {
        await first.onCreateBiodata();
        clock = clock.add(const Duration(minutes: 30));
      }
      expect(loader.shownCount, AdConfig.interstitialDailyCap);

      final second = build();
      clock = clock.add(const Duration(hours: 2));
      await second.onCreateBiodata();

      expect(loader.shownCount, AdConfig.interstitialDailyCap);
    });
  });

  group('AdConfig', () {
    test('reports test units so a misconfigured release is catchable', () {
      // The defines are absent in a test run, so all three are test units.
      expect(AdConfig.isUsingTestUnits, isTrue);
      expect(AdConfig.interstitialUnitId, AdConfig.testInterstitialUnitId);
      expect(AdConfig.rewardedUnitId, AdConfig.testRewardedUnitId);
    });

    test('every test unit is one of Google published sample IDs', () {
      // All of Google's samples share this publisher. A typo here would show a
      // real ad in a test run, or no ad at all in a release.
      for (final unit in [
        AdConfig.testBannerUnitId,
        AdConfig.testInterstitialUnitId,
        AdConfig.testRewardedUnitId,
      ]) {
        expect(unit, startsWith('ca-app-pub-3940256099942544/'));
      }
    });
  });
}
