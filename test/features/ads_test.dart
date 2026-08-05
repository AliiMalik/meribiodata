import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/features/ads/ad_config.dart';
import 'package:meribiodata/features/ads/consent_gate.dart';

import '../support/fake_consent.dart';

void main() {
  group('ad unit configuration (§8)', () {
    test('defaults to Google test units, so nothing real is committed', () {
      expect(AdConfig.bannerUnitId, AdConfig.testBannerUnitId);
      expect(AdConfig.isUsingTestUnits, isTrue);
    });

    test('the committed unit id is a Google test id, not a real one', () {
      // Real AdMob ids are account-specific. If this ever changes, someone has
      // committed a production id — which §8 forbids.
      expect(AdConfig.bannerUnitId, startsWith('ca-app-pub-3940256099942544/'));
    });
  });

  group('where banners are allowed (§8)', () {
    test('Home and the Form Editor are allowed', () {
      expect(AdConfig.allowsBannerOn('home'), isTrue);
      expect(AdConfig.allowsBannerOn('editor'), isTrue);
    });

    test('the export screen is not', () {
      // The export and share buttons are the highest-value taps in the app.
      // An ad beside them invites accidental clicks, which is an AdMob policy
      // risk that can suspend an account — not merely a UX annoyance.
      expect(AdConfig.allowsBannerOn('export'), isFalse);
    });

    test('screens nobody listed get nothing, by default', () {
      for (final screen in [
        'templates',
        'schema',
        'settings',
        'waitlist',
        'onboarding',
        '',
      ]) {
        expect(AdConfig.allowsBannerOn(screen), isFalse, reason: screen);
      }
    });
  });

  group('consent gates ad initialisation', () {
    test('consent is requested before ads initialise', () async {
      final order = <String>[];
      final platform = _RecordingPlatform(order, permitted: true);
      final gate = ConsentGate(
        platform: platform,
        initialiseAds: () async => order.add('initialiseAds'),
      );

      await gate.resolve();

      // The ordering is the whole point of §8's requirement — initialising
      // first and asking afterwards still "works", which is why it is an easy
      // mistake to ship.
      expect(order, ['requestConsent', 'canRequestAds', 'initialiseAds']);
    });

    test('ads become available when consent permits', () async {
      final gate = ConsentGate(
        platform: FakeConsentPlatform(permitted: true),
        initialiseAds: () async {},
      );

      await gate.resolve();

      expect(gate.status, ConsentStatus.canRequestAds);
      expect(gate.canShowAds, isTrue);
    });

    test('a refusal means no ads and no SDK initialisation', () async {
      var initialised = false;
      final gate = ConsentGate(
        platform: FakeConsentPlatform(),
        initialiseAds: () async => initialised = true,
      );

      await gate.resolve();

      expect(gate.status, ConsentStatus.cannotRequestAds);
      expect(gate.canShowAds, isFalse);
      expect(initialised, isFalse);
    });

    test(
      'a failing consent form disables ads rather than allowing them',
      () async {
        var initialised = false;
        final gate = ConsentGate(
          platform: FakeConsentPlatform(throwOnRequest: true),
          initialiseAds: () async => initialised = true,
        );

        await gate.resolve();

        // Offline, no Play services, or a form that would not load. Showing ads
        // because the consent check errored is the one outcome that must never
        // happen.
        expect(gate.status, ConsentStatus.failed);
        expect(gate.canShowAds, isFalse);
        expect(initialised, isFalse);
      },
    );

    test('a failing status query also disables ads', () async {
      final gate = ConsentGate(
        platform: FakeConsentPlatform(throwOnQuery: true),
        initialiseAds: () async {},
      );

      await gate.resolve();

      expect(gate.canShowAds, isFalse);
    });

    test('an SDK that fails to initialise leaves ads off', () async {
      final gate = ConsentGate(
        platform: FakeConsentPlatform(permitted: true),
        initialiseAds: () async => throw StateError('no Play services'),
      );

      await gate.resolve();

      expect(gate.status, ConsentStatus.failed);
      expect(gate.canShowAds, isFalse);
    });

    test('starts closed, before anything has been resolved', () {
      final gate = ConsentGate(
        platform: FakeConsentPlatform(permitted: true),
        initialiseAds: () async {},
      );

      expect(gate.status, ConsentStatus.unknown);
      expect(gate.canShowAds, isFalse);
    });

    test('resolving twice does not initialise the SDK twice', () async {
      var initialisations = 0;
      final gate = ConsentGate(
        platform: FakeConsentPlatform(permitted: true),
        initialiseAds: () async => initialisations++,
      );

      await gate.resolve();
      await gate.resolve();

      expect(initialisations, 1);
    });

    test(
      'notifies listeners so a banner can appear without navigation',
      () async {
        var notifications = 0;
        final gate = ConsentGate(
          platform: FakeConsentPlatform(permitted: true),
          initialiseAds: () async {},
        )..addListener(() => notifications++);

        await gate.resolve();

        expect(notifications, greaterThan(0));
      },
    );
  });
}

class _RecordingPlatform implements ConsentPlatform {
  _RecordingPlatform(this.order, {required this.permitted});

  final List<String> order;
  final bool permitted;

  @override
  Future<void> requestConsent() async => order.add('requestConsent');

  @override
  Future<bool> canRequestAds() async {
    order.add('canRequestAds');
    return permitted;
  }
}
