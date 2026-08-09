import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/features/ads/rewarded_ads.dart';
import 'package:meribiodata/features/templates/template_unlocks.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// The two doors out of a locked template (D19).
///
/// Watch an ad for 24 hours, or buy Premium and never see this sheet again.
/// Both are offered together on purpose: the ad is the one most people will
/// take, and seeing what it costs to stop watching ads is what makes Premium
/// concrete rather than abstract.
///
/// Returns true when the template is now usable.
Future<bool> showTemplateUnlockSheet(
  BuildContext context,
  DocumentTemplate template, {

  /// Set when the user has hit an unlock that ran out rather than one they
  /// have never had. Same choices, different wording — being told "unlock
  /// this" when you unlocked it yesterday reads as a bug.
  bool expired = false,
}) async {
  final unlocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _UnlockSheet(template: template, expired: expired),
  );
  return unlocked ?? false;
}

class _UnlockSheet extends StatefulWidget {
  const _UnlockSheet({required this.template, required this.expired});

  final DocumentTemplate template;
  final bool expired;

  @override
  State<_UnlockSheet> createState() => _UnlockSheetState();
}

class _UnlockSheetState extends State<_UnlockSheet> {
  bool _busy = false;

  Future<void> _watch() async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final unlocks = context.read<TemplateUnlocks>();

    setState(() => _busy = true);
    final outcome = await context.read<RewardedAds>().show();
    if (!mounted) return;

    switch (outcome) {
      case RewardOutcome.earned:
        // Granted from the reward callback alone. Closing an ad early lands in
        // `dismissed`, and must not unlock anything.
        await unlocks.grant(widget.template.id);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.templateUnlockEarned)),
        );
        navigator.pop(true);
      case RewardOutcome.dismissed:
        setState(() => _busy = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.templateUnlockDismissed)),
        );
      case RewardOutcome.unavailable:
        setState(() => _busy = false);
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.templateUnlockUnavailable)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;
    final adsAvailable = context.read<RewardedAds>().isAvailable;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline, color: AppColors.primaryGreen),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    widget.expired
                        ? l10n.templateExpiredTitle
                        : l10n.templateUnlockTitle(widget.template.name),
                    style: text.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.expired
                  ? l10n.templateExpiredBody
                  : l10n.templateUnlockBody,
              style: text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Hidden rather than disabled when ads cannot be shown at all — no
            // consent, no network, no Play services. A button that explains
            // why it will not work is worse than no button.
            if (adsAvailable) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _watch,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle_outline),
                label: Text(l10n.templateUnlockWatch),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      Navigator.of(context).pop(false);
                      unawaited(context.push(AppRoutes.premium));
                    },
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(l10n.templateUnlockPremium),
            ),
          ],
        ),
      ),
    );
  }
}
