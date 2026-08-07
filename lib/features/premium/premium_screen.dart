import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/features/premium/billing.dart';
import 'package:meribiodata/features/premium/entitlements.dart';
import 'package:meribiodata/features/premium/premium_products.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// Where Premium is bought (#33).
///
/// Replaces the Matchmaker Pro waitlist, which is withdrawn — see D17.
///
/// Two rules shape this screen:
///
/// * **Nothing is locked.** Premium removes ads and the watermark; it adds no
///   feature and gates none. Every price shown here is optional in the fullest
///   sense, and the screen says so rather than implying a crippled free tier.
/// * **Prices come from Play, never from the app.** What is displayed is the
///   string Google built for this user's country and currency. Hard-coding
///   "$1" would be wrong in Pakistan on day one and wrong everywhere else by
///   the next exchange-rate move.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  late Future<List<BillingProduct>> _offers;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _offers = context.read<Entitlements>().offers();
  }

  Future<void> _buy(BillingProduct product) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final entitlements = context.read<Entitlements>();

    setState(() => _busy = true);
    final result = await entitlements.buy(product);
    if (!mounted) return;
    setState(() => _busy = false);

    final message = switch (result) {
      PurchaseResult.bought => l10n.premiumThanks,
      // Not an error, and not phrased as one. Carrier billing in Pakistan can
      // sit pending for a long time, and the user must be told it is fine to
      // walk away rather than left staring at a spinner.
      PurchaseResult.pending => l10n.premiumPending,
      PurchaseResult.cancelled => l10n.premiumCancelled,
      PurchaseResult.failed => l10n.premiumFailed,
      PurchaseResult.unavailable => l10n.premiumUnavailable,
    };
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final entitlements = context.read<Entitlements>();

    setState(() => _busy = true);
    await entitlements.restore();
    if (!mounted) return;
    setState(() => _busy = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          entitlements.isPremium ? l10n.premiumThanks : l10n.premiumRestored,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;
    final isPremium = context.select<Entitlements, bool>((e) => e.isPremium);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.premiumTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text(l10n.premiumHeadline, style: text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.premiumBody, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.xl),

          _Benefit(icon: Icons.block, text: l10n.premiumBenefitNoAds),
          _Benefit(
            icon: Icons.branding_watermark_outlined,
            text: l10n.premiumBenefitNoWatermark,
          ),
          _Benefit(
            icon: Icons.favorite_outline,
            text: l10n.premiumBenefitSupports,
          ),
          const SizedBox(height: AppSpacing.xl),

          if (isPremium)
            _AlreadyPremium(plan: context.read<Entitlements>().plan)
          else
            _Offers(busy: _busy, offers: _offers, onBuy: _buy),

          const SizedBox(height: AppSpacing.lg),
          // Play policy requires a way back to a purchase after a reinstall or
          // a new phone. It is also the first thing a user looks for when they
          // paid and the app has forgotten.
          TextButton(
            onPressed: _busy ? null : _restore,
            child: Text(l10n.premiumRestore),
          ),
        ],
      ),
    );
  }
}

class _Offers extends StatelessWidget {
  const _Offers({
    required this.busy,
    required this.offers,
    required this.onBuy,
  });

  final bool busy;
  final Future<List<BillingProduct>> offers;
  final Future<void> Function(BillingProduct) onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return FutureBuilder<List<BillingProduct>>(
      future: offers,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data ?? const <BillingProduct>[];
        if (products.isEmpty) {
          // No Play Store, no connection, or the products are not live in Play
          // Console yet. Never a dead end — the app is fully usable either way.
          return Text(
            l10n.premiumNoOffers,
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }

        return Column(
          children: [
            for (final product in products) ...[
              _OfferCard(
                product: product,
                busy: busy,
                onBuy: () => onBuy(product),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.product,
    required this.busy,
    required this.onBuy,
  });

  final BillingProduct product;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;
    final isLifetime = product.plan == PremiumPlan.lifetime;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isLifetime
                        ? l10n.premiumLifetimeLabel
                        : l10n.premiumMonthlyLabel,
                    style: text.titleMedium,
                  ),
                ),
                if (isLifetime)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      l10n.premiumBestValue,
                      style: text.labelSmall?.copyWith(
                        color: AppColors.onAccentGold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // Google's own localised string, never assembled here.
            Text(product.price, style: text.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onBuy,
                child: Text(l10n.premiumBuy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlreadyPremium extends StatelessWidget {
  const _AlreadyPremium({required this.plan});

  final PremiumPlan? plan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.secondaryGreen),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                plan == PremiumPlan.monthly
                    ? l10n.premiumActiveMonthly
                    : l10n.premiumActiveLifetime,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.secondaryGreen),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}
