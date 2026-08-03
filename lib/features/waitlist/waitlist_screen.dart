import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';

/// The only Phase 2 surface allowed in the app (§0.1, §7.8).
///
/// Captures interest and nothing else. No CRM screen, tab or navigation entry
/// may ever be reachable from here. The submission mechanism itself is an open
/// question (`mailto:` vs a third-party form) and lands in M4 — it changes the
/// privacy policy text under NFR-5, so it is not implemented on a guess.
class WaitlistScreen extends StatelessWidget {
  const WaitlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.waitlistTitle)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentGold,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Text(
                l10n.waitlistComingSoon,
                style: text.labelLarge?.copyWith(
                  color: AppColors.onAccentGold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.waitlistBody, style: text.bodyLarge),
          ],
        ),
      ),
    );
  }
}
