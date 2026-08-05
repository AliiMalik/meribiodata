import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/features/ads/ad_config.dart';
import 'package:meribiodata/features/ads/consent_gate.dart';
import 'package:provider/provider.dart';

/// An anchored adaptive banner (§8).
///
/// Three rules this widget exists to keep:
///
/// * **Reserved space, not an overlay.** It sits in the layout, so it can never
///   cover a form field, the preview or an export control at any screen size.
/// * **Collapses cleanly.** No consent, no ad, no network — the slot takes zero
///   height and the app is fully usable. Airplane mode is an explicit
///   acceptance case, not a hope.
/// * **Allowlisted screens only.** [AdConfig.allowsBannerOn] decides; a screen
///   that is not on the list gets nothing.
class BannerSlot extends StatefulWidget {
  const BannerSlot({required this.screenId, super.key});

  /// Matched against [AdConfig.bannerScreens].
  final String screenId;

  @override
  State<BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<BannerSlot> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_maybeLoad());
  }

  @override
  void dispose() {
    unawaited(_ad?.dispose());
    super.dispose();
  }

  Future<void> _maybeLoad() async {
    if (_requested) return;
    if (!AdConfig.allowsBannerOn(widget.screenId)) {
      debugPrint('BannerSlot(${widget.screenId}): not an ad screen (§8)');
      return;
    }
    if (!context.read<ConsentGate>().canShowAds) return;

    _requested = true;

    // Adaptive: the height is chosen from the device width, which is what
    // "anchored adaptive" means and why the slot must measure before reserving.
    final width = MediaQuery.sizeOf(context).width.truncate();
    // Falls back to a standard banner when the adaptive size cannot be
    // computed. Returning early instead — as this did originally — collapsed
    // the slot with no ad and no log line, which on a device is
    // indistinguishable from "ads are switched off".
    final size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width) ??
        AdSize.banner;
    if (!mounted) return;

    debugPrint(
      'BannerSlot(${widget.screenId}): requesting ${size.width}x${size.height}',
    );

    final ad = BannerAd(
      size: size,
      adUnitId: AdConfig.bannerUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('BannerSlot(${widget.screenId}): loaded');
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // Offline or no fill. Collapse rather than leaving a grey gap.
          debugPrint('Banner failed to load: $error');
          unawaited(ad.dispose());
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );

    _ad = ad;
    await ad.load();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when consent resolves so the slot can appear without a
    // navigation event.
    final canShowAds = context.select<ConsentGate, bool>((g) => g.canShowAds);
    if (canShowAds && !_requested) unawaited(_maybeLoad());

    final ad = _ad;
    if (!canShowAds || !_loaded || ad == null) {
      // Zero height: the slot genuinely disappears rather than reserving a
      // blank strip the user would read as a rendering bug.
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
