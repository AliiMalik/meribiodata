import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

/// Roles the app needs that Material's [ColorScheme] has no slot for.
///
/// Reached with `Theme.of(context).extension<AppSemantics>()!`, or more simply
/// through `context.semantics`. It exists so a call site never has to name a
/// palette constant to get a warning panel: naming one picks a single theme's
/// colour, and the other theme is then wrong by construction.
@immutable
class AppSemantics extends ThemeExtension<AppSemantics> {
  const AppSemantics({
    required this.warningContainer,
    required this.onWarningContainer,
    required this.badge,
    required this.onBadge,
  });

  /// The fill behind a caution message — the "this version carries your phone
  /// number" panel on the export screen.
  final Color warningContainer;

  /// Text and icons drawn on [warningContainer].
  final Color onWarningContainer;

  /// The gold used for the Premium and Locked badges.
  ///
  /// Deliberately the *same* colour in both themes, unlike everything else
  /// here: it is a brand mark rather than a surface, it is bright enough to
  /// carry dark ink against either background, and a badge that changed colour
  /// at night would stop reading as the same thing.
  final Color badge;

  /// Ink on [badge]. Dark in both themes — white on gold is 2.27:1.
  final Color onBadge;

  @override
  AppSemantics copyWith({
    Color? warningContainer,
    Color? onWarningContainer,
    Color? badge,
    Color? onBadge,
  }) => AppSemantics(
    warningContainer: warningContainer ?? this.warningContainer,
    onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    badge: badge ?? this.badge,
    onBadge: onBadge ?? this.onBadge,
  );

  @override
  AppSemantics lerp(ThemeExtension<AppSemantics>? other, double t) {
    if (other is! AppSemantics) return this;
    return AppSemantics(
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      badge: Color.lerp(badge, other.badge, t)!,
      onBadge: Color.lerp(onBadge, other.onBadge, t)!,
    );
  }
}

/// Shorthand for the two theme lookups every widget needs.
extension AppThemeContext on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  AppSemantics get semantics => Theme.of(this).extension<AppSemantics>()!;
}

/// The tokens that differ between light and dark, so everything else — spacing,
/// shapes, line heights, the whole component tree below — is written once.
///
/// Building the dark theme as a second copy of the light one is how the two
/// drift: a rounded corner gets adjusted in one and not the other, and nobody
/// notices for a release. Here there is one component tree and two palettes.
enum _Palette {
  light(
    // primaryDark, not primaryGreen: white on #16A34A is 3.30:1, which fails
    // AA for a 14sp button label.
    primary: AppColors.primaryDark,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.lightGreen,
    onPrimaryContainer: AppColors.primaryDark,
    accent: AppColors.accentTeal,
    onAccent: AppColors.white,
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceHigh: AppColors.surface,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    divider: AppColors.divider,
    error: AppColors.error,
    onError: AppColors.white,
    brightness: Brightness.light,
    appBarBackground: AppColors.primaryDark,
    appBarForeground: AppColors.white,
    focusRing: AppColors.primaryGreen,
    snackBackground: AppColors.textPrimary,
    snackForeground: AppColors.white,
    warningContainer: AppColors.warningContainer,
    onWarningContainer: AppColors.onWarningContainer,
  ),

  dark(
    primary: AppColors.darkPrimary,
    onPrimary: AppColors.onDarkPrimary,
    primaryContainer: AppColors.darkPrimaryContainer,
    onPrimaryContainer: AppColors.onDarkPrimaryContainer,
    accent: AppColors.darkAccentTeal,
    onAccent: AppColors.onDarkPrimary,
    background: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    surfaceHigh: AppColors.darkSurfaceHigh,
    textPrimary: AppColors.darkTextPrimary,
    textSecondary: AppColors.darkTextSecondary,
    divider: AppColors.darkDivider,
    error: AppColors.darkError,
    onError: AppColors.onDarkPrimary,
    brightness: Brightness.dark,
    // The app bar takes a surface colour rather than the brand green: a
    // saturated green bar against a near-black body is the single loudest
    // thing on the screen at night.
    appBarBackground: AppColors.darkSurface,
    appBarForeground: AppColors.darkTextPrimary,
    focusRing: AppColors.darkPrimary,
    snackBackground: AppColors.darkSurfaceHigh,
    snackForeground: AppColors.darkTextPrimary,
    warningContainer: AppColors.darkWarningContainer,
    onWarningContainer: AppColors.darkOnWarningContainer,
  );

  const _Palette({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.error,
    required this.onError,
    required this.brightness,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.focusRing,
    required this.snackBackground,
    required this.snackForeground,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color accent;
  final Color onAccent;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final Color error;
  final Color onError;
  final Brightness brightness;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color focusRing;
  final Color snackBackground;
  final Color snackForeground;
  final Color warningContainer;
  final Color onWarningContainer;
}

/// The app's single source of visual truth.
///
/// Note what is *not* here: the document. A biodata always renders on white
/// paper with dark ink, in every theme, because it is printed and forwarded
/// rather than read inside the app. `TemplateStyle` owns that, deliberately
/// apart from this file (§10).
abstract final class AppTheme {
  /// Builds the theme for a given UI locale.
  ///
  /// The font and line-height come from the [LanguageDescriptor] rather than
  /// being hardcoded, so switching the interface to Urdu picks up the bundled
  /// Nastaliq face and its taller leading automatically — and adding a
  /// language stays a data-only change (§5).
  static ThemeData lightFor(LanguageDescriptor language) =>
      _themeFor(language, _Palette.light);

  static ThemeData darkFor(LanguageDescriptor language) =>
      _themeFor(language, _Palette.dark);

  static ThemeData _themeFor(LanguageDescriptor language, _Palette p) {
    final scheme = ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.primaryContainer,
      onPrimaryContainer: p.onPrimaryContainer,
      secondary: p.accent,
      onSecondary: p.onAccent,
      error: p.error,
      onError: p.onError,
      surface: p.background,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceHigh,
      onSurfaceVariant: p.textSecondary,
      outlineVariant: p.divider,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: language.uiFontFamily,
      fontFamilyFallback: language.uiFontFallback,
      scaffoldBackgroundColor: p.background,
    );

    return base.copyWith(
      textTheme: _textTheme(base.textTheme, language, p),
      appBarTheme: AppBarTheme(
        backgroundColor: p.appBarBackground,
        foregroundColor: p.appBarForeground,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: p.divider,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: p.divider),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: p.onPrimary,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
          side: BorderSide(color: p.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          minimumSize: const Size(0, AppSpacing.minTapTarget),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: p.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: p.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          borderSide: BorderSide(color: p.focusRing, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.accent,
        textColor: p.textPrimary,
        minVerticalPadding: AppSpacing.md,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.snackBackground,
        contentTextStyle: TextStyle(color: p.snackForeground),
        behavior: SnackBarBehavior.floating,
      ),
      extensions: [
        AppSemantics(
          warningContainer: p.warningContainer,
          onWarningContainer: p.onWarningContainer,
          badge: AppColors.accentGold,
          onBadge: AppColors.onAccentGold,
        ),
      ],
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    LanguageDescriptor language,
    _Palette p,
  ) {
    final h = language.uiLineHeight;
    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(
        color: p.textPrimary,
        fontWeight: FontWeight.w700,
        height: h,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: p.textPrimary,
        fontWeight: FontWeight.w600,
        height: h,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: p.textPrimary,
        fontWeight: FontWeight.w600,
        height: h,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: p.textPrimary, height: h),
      bodyMedium: base.bodyMedium?.copyWith(color: p.textPrimary, height: h),
      bodySmall: base.bodySmall?.copyWith(color: p.textSecondary, height: h),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        height: h,
      ),
    );
  }
}
