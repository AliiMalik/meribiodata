import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/widgets/language_option_tile.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';

/// Four screens: what this is, the privacy promise, language selection, and
/// what Premium is. Skippable, per §7.1.
///
/// Premium is last on purpose. A price shown before the user knows what the app
/// does reads as a paywall; shown after the privacy promise and the language
/// choice, it reads as an offer — and the panel leads with the fact that
/// everything works without paying (D17).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() => context.read<AppPreferences>().completeOnboarding();

  void _next() {
    if (_page == _pageCount - 1) {
      unawaited(_finish());
      return;
    }
    unawaited(
      _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: _finish,
                child: Text(l10n.onboardingSkip),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _Panel(
                    icon: Icons.description_outlined,
                    title: l10n.onboardingWelcomeTitle,
                    body: l10n.onboardingWelcomeBody,
                  ),
                  _Panel(
                    icon: Icons.lock_outline,
                    title: l10n.onboardingPrivacyTitle,
                    body: l10n.onboardingPrivacyBody,
                  ),
                  const _LanguagePanel(),
                  const _PremiumPanel(),
                ],
              ),
            ),
            _Dots(count: _pageCount, active: _page),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    _page == _pageCount - 1
                        // "Continue for free" rather than "Start": the last
                        // panel shows a price, and the button under it must
                        // say plainly that carrying on costs nothing.
                        ? l10n.premiumOnboardingSkip
                        : l10n.onboardingNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.primaryGreen),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: text.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Text(body, style: text.bodyLarge, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _LanguagePanel extends StatelessWidget {
  const _LanguagePanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final preferences = context.watch<AppPreferences>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onboardingLanguageTitle,
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final language in AppLanguages.uiLocales)
            LanguageOptionTile(
              language: language,
              selected: language.code == preferences.uiLanguage.code,
              onTap: () => preferences.setUiLanguage(language),
            ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < count; i++)
        Container(
          width: AppSpacing.sm,
          height: AppSpacing.sm,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i == active ? AppColors.primaryGreen : AppColors.divider,
          ),
        ),
    ],
  );
}

/// The last onboarding panel: what Premium is, and that nothing needs it.
class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            size: 64,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.premiumOnboardingTitle,
            style: text.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.premiumOnboardingBody,
            style: text.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          // A way in for the minority who want it now, without making the
          // majority step around a paywall. The primary button below still
          // says "Continue for free".
          TextButton(
            onPressed: () => context.push(AppRoutes.premium),
            child: Text(l10n.premiumTitle),
          ),
        ],
      ),
    );
  }
}
