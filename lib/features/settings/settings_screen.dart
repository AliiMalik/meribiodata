import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/widgets/language_option_tile.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';

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
          SwitchListTile(
            secondary: const Icon(Icons.translate),
            title: Text(l10n.settingsRomanInput),
            subtitle: Text(l10n.romanInputOff),
            value: preferences.romanInputDefault,
            onChanged: (enabled) =>
                preferences.setRomanInputDefault(enabled: enabled),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(l10n.backupTitle),
            subtitle: Text(
              l10n.backupExplain,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => context.push(AppRoutes.backup),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: Text(l10n.settingsPrivacyPolicy),
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
            subtitle: Text('MeriBiodata 1.0.0', style: text.bodySmall),
          ),
        ],
      ),
    );
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
