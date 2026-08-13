import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/config/legal_links.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/widgets/language_option_tile.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// §7.7. M1 ships UI language and digit style — the two settings that already
/// have real state behind them. Units, theme, backup/restore, Roman input and
/// delete-all-data arrive with the milestones that own them.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final preferences = context.watch<AppPreferences>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          _SectionHeader(l10n.settingsUiLanguage),
          for (final language in AppLanguages.uiLocales)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
              child: LanguageOptionTile(
                language: language,
                selected: language.code == preferences.uiLanguage.code,
                onTap: () => preferences.setUiLanguage(language),
              ),
            ),
          const Divider(),
          _SectionHeader(l10n.settingsDigitStyle),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SegmentedButton<DigitStyle>(
              segments: [
                ButtonSegment(
                  value: DigitStyle.western,
                  label: Text(l10n.settingsDigitWestern),
                ),
                ButtonSegment(
                  value: DigitStyle.easternArabic,
                  label: Text(l10n.settingsDigitEastern),
                ),
              ],
              selected: {preferences.digitStyle},
              onSelectionChanged: (selection) =>
                  preferences.setDigitStyle(selection.first),
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsUnits),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.settingsUnitHeight, style: text.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<LengthUnit>(
                  segments: [
                    ButtonSegment(
                      value: LengthUnit.feetInches,
                      label: Text(l10n.settingsUnitFeet),
                    ),
                    ButtonSegment(
                      value: LengthUnit.centimetres,
                      label: Text(l10n.settingsUnitCentimetres),
                    ),
                  ],
                  selected: {preferences.heightUnit},
                  onSelectionChanged: (s) => preferences.setHeightUnit(s.first),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.settingsUnitWeight, style: text.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<MassUnit>(
                  segments: [
                    ButtonSegment(
                      value: MassUnit.kilograms,
                      label: Text(l10n.settingsUnitKilograms),
                    ),
                    ButtonSegment(
                      value: MassUnit.pounds,
                      label: Text(l10n.settingsUnitPounds),
                    ),
                  ],
                  selected: {preferences.weightUnit},
                  onSelectionChanged: (s) => preferences.setWeightUnit(s.first),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.settingsUnitsHint, style: text.bodySmall),
              ],
            ),
          ),
          const Divider(),
          _SectionHeader(l10n.settingsTheme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(l10n.settingsThemeSystem),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(l10n.settingsThemeLight),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(l10n.settingsThemeDark),
                    ),
                  ],
                  selected: {preferences.themeMode},
                  onSelectionChanged: (s) => preferences.setThemeMode(s.first),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Worth saying out loud: a user who turns on dark mode and then
                // exports would otherwise reasonably expect a dark document.
                Text(l10n.settingsThemeHint, style: text.bodySmall),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.translate),
            title: Text(l10n.settingsRomanInput),
            subtitle: Text(l10n.romanInputOff),
            value: preferences.romanInputDefault,
            onChanged: (enabled) =>
                preferences.setRomanInputDefault(enabled: enabled),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_outlined),
            title: Text(l10n.syncTitle),
            subtitle: Text(
              l10n.syncExplain,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => context.push(AppRoutes.sync),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: Text(l10n.settingsPrivacyPolicy),
            subtitle: Text(
              l10n.settingsPrivacyPolicyHint,
              style: text.bodySmall,
            ),
            onTap: () => unawaited(_openPrivacyPolicy(context)),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(l10n.settingsLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appName,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.settingsAbout),
            subtitle: Text(
              'Pak Marriage Biodata Maker 1.0.0',
              style: text.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens in the browser rather than a webview: in-app webviews are ruled out
/// (D8, kept by D17), and the policy is a public page with no reason to be
/// embedded.
Future<void> _openPrivacyPolicy(BuildContext context) async {
  final l10n = AppL10n.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final opened = await launchUrl(
    Uri.parse(LegalLinks.privacyPolicy),
    mode: LaunchMode.externalApplication,
  ).onError((_, _) => false);

  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.errorNoBrowser)));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.lg,
      AppSpacing.sm,
    ),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );
}
