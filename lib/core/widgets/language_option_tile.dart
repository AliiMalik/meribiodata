import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

/// A selectable language row.
///
/// A whole-row tap target rather than a radio button: the primary user is
/// often a parent in their 50s or 60s, and the language name is always shown
/// in its own script and direction so it is legible before the UI switches.
class LanguageOptionTile extends StatelessWidget {
  const LanguageOptionTile({
    required this.language,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final LanguageDescriptor language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      minVerticalPadding: AppSpacing.md,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      selected: selected,
      selectedTileColor: context.colors.primaryContainer,
      // Without this the selected row's text takes `colorScheme.primary`, which
      // in dark mode is a light green sitting on the light green fill.
      selectedColor: context.colors.onPrimaryContainer,
      // The name is rendered in its own script but aligned to the *list's*
      // direction, so every row lines up. Bidi shapes an RTL word correctly
      // inside an LTR paragraph; only alignment would differ, and a ragged
      // picker is harder to scan than a consistent one.
      title: Text(
        language.nativeName,
        style: text.titleMedium?.copyWith(
          fontFamily: language.uiFontFamily,
          fontFamilyFallback: language.uiFontFallback,
          height: language.uiLineHeight,
          // Both lines carry a colour from the text theme, which overrides
          // `selectedColor`, so the selected fill has to be answered here.
          color: selected ? context.colors.onPrimaryContainer : null,
        ),
      ),
      subtitle: language.nativeName == language.englishName
          ? null
          : Text(
              language.englishName,
              style: text.bodySmall?.copyWith(
                color: selected ? context.colors.onPrimaryContainer : null,
              ),
            ),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: context.colors.onPrimaryContainer,
            )
          : null,
    );
  }
}
