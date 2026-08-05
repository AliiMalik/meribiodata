import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the waitlist form lives.
///
/// A build-time constant, not a secret — it is a public form URL. Replacing it
/// is a one-line change; see open question 8 in `docs/decisions.md`.
abstract final class WaitlistForm {
  // TODO(alihmalik): replace with the real Google Form URL once it exists.
  static const url = String.fromEnvironment(
    'WAITLIST_FORM_URL',
    defaultValue: 'https://forms.gle/meribiodata-matchmaker-pro-placeholder',
  );

  static bool get isPlaceholder => url.contains('placeholder');
}

/// The only Phase 2 surface allowed in the app (§0.1, §7.8).
///
/// Captures interest and nothing else. No CRM screen, tab or navigation entry
/// is reachable from here.
///
/// Per `docs/decisions.md` D8 the form opens in the user's **browser**: the app
/// never touches, stores or transmits what is typed into it. That is what keeps
/// the NFR-5 disclosure honest and narrow — "this button opens a form hosted by
/// a third party", not "we collect your details".
class WaitlistScreen extends StatelessWidget {
  const WaitlistScreen({super.key, this.launcher = launchUrl});

  /// Injectable so the failure paths can be tested without a browser.
  final Future<bool> Function(Uri, {LaunchMode mode}) launcher;

  Future<void> _open(BuildContext context) async {
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final opened = await launcher(
        Uri.parse(WaitlistForm.url),
        mode: LaunchMode.externalApplication,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            opened ? l10n.waitlistOpened : l10n.waitlistNoBrowser,
          ),
        ),
      );
    } on Object {
      // No browser installed, or no connection once it opened. §7.8 requires a
      // visible outcome either way — never a button that silently does nothing.
      messenger.showSnackBar(SnackBar(content: Text(l10n.waitlistOffline)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.waitlistTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
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
                style: text.labelLarge?.copyWith(color: AppColors.onAccentGold),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.waitlistBody, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.xl),

          // Stated before the button, not after: the user should know what is
          // being asked and where it goes before they tap (NFR-5).
          _Disclosure(
            icon: Icons.list_alt_outlined,
            text: l10n.waitlistWhatWeAsk,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Disclosure(
            icon: Icons.open_in_new,
            text: l10n.waitlistOpensInBrowser,
          ),
          const SizedBox(height: AppSpacing.xl),

          FilledButton.icon(
            onPressed: () => _open(context),
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.waitlistOpenForm),
          ),
        ],
      ),
    );
  }
}

class _Disclosure extends StatelessWidget {
  const _Disclosure({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    ],
  );
}
