import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/theme/app_colors.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The build prompt (§10) requires AA contrast on every text-on-surface pair.
/// These tests encode the rules that survived measurement, so a future palette
/// change that breaks one fails CI instead of shipping.
void main() {
  const aaBody = 4.5;
  const aaLarge = 3.0;

  group('body text pairs meet WCAG AA (4.5:1)', () {
    final pairs = <String, (Color, Color)>{
      'textPrimary on background': (
        AppColors.textPrimary,
        AppColors.background,
      ),
      'textPrimary on surface': (AppColors.textPrimary, AppColors.surface),
      'textSecondary on background': (
        AppColors.textSecondary,
        AppColors.background,
      ),
      'textSecondary on surface': (
        AppColors.textSecondary,
        AppColors.surface,
      ),
      // The filled-button pairing. This is why buttons use primaryDark rather
      // than primaryGreen: white on #16A34A measures 3.30:1.
      'onPrimary on primaryDark': (
        AppColors.onPrimary,
        AppColors.primaryDark,
      ),
      'primaryDark on background': (
        AppColors.primaryDark,
        AppColors.background,
      ),
      'accentTeal on background': (AppColors.accentTeal, AppColors.background),
      'onError on error': (AppColors.onError, AppColors.error),
      'error on background': (AppColors.error, AppColors.background),
      // Bright fills carry dark text — white on them is ~2.2:1.
      'onSuccess on success': (AppColors.onSuccess, AppColors.success),
      'onWarning on warning': (AppColors.onWarning, AppColors.warning),
      'onAccentGold on accentGold': (
        AppColors.onAccentGold,
        AppColors.accentGold,
      ),
      'onSecondaryGreen on secondaryGreen': (
        AppColors.onSecondaryGreen,
        AppColors.secondaryGreen,
      ),
      'onLightGreen on lightGreen': (
        AppColors.onLightGreen,
        AppColors.lightGreen,
      ),
      'primaryDark on lightGreen': (
        AppColors.primaryDark,
        AppColors.lightGreen,
      ),
      'onWarningContainer on warningContainer': (
        AppColors.onWarningContainer,
        AppColors.warningContainer,
      ),
    };

    for (final entry in pairs.entries) {
      test(entry.key, () {
        final ratio = contrastRatio(entry.value.$1, entry.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(aaBody),
          reason:
              '${entry.key} is ${ratio.toStringAsFixed(2)}:1, below AA for '
              'body text. Either darken the foreground or restrict this pair '
              'to large text and move it to the large-text group.',
        );
      });
    }
  });

  group('dark theme body text pairs meet WCAG AA (4.5:1)', () {
    // A dark theme is not the light one inverted, and it is where a palette
    // most easily fails quietly: `primaryDark` on a near-black surface is
    // 1.6:1 and simply disappears. Every dark pair is measured here for the
    // same reason the light ones are.
    final pairs = <String, (Color, Color)>{
      'darkTextPrimary on darkBackground': (
        AppColors.darkTextPrimary,
        AppColors.darkBackground,
      ),
      'darkTextPrimary on darkSurface': (
        AppColors.darkTextPrimary,
        AppColors.darkSurface,
      ),
      'darkTextPrimary on darkSurfaceHigh': (
        AppColors.darkTextPrimary,
        AppColors.darkSurfaceHigh,
      ),
      'darkTextSecondary on darkBackground': (
        AppColors.darkTextSecondary,
        AppColors.darkBackground,
      ),
      'darkTextSecondary on darkSurface': (
        AppColors.darkTextSecondary,
        AppColors.darkSurface,
      ),
      'darkTextSecondary on darkSurfaceHigh': (
        AppColors.darkTextSecondary,
        AppColors.darkSurfaceHigh,
      ),
      'darkPrimary on darkBackground': (
        AppColors.darkPrimary,
        AppColors.darkBackground,
      ),
      'darkPrimary on darkSurface': (
        AppColors.darkPrimary,
        AppColors.darkSurface,
      ),
      'darkAccentTeal on darkSurface': (
        AppColors.darkAccentTeal,
        AppColors.darkSurface,
      ),
      'onDarkPrimary on darkPrimary': (
        AppColors.onDarkPrimary,
        AppColors.darkPrimary,
      ),
      'onDarkPrimaryContainer on darkPrimaryContainer': (
        AppColors.onDarkPrimaryContainer,
        AppColors.darkPrimaryContainer,
      ),
      'darkOnWarningContainer on darkWarningContainer': (
        AppColors.darkOnWarningContainer,
        AppColors.darkWarningContainer,
      ),
      'darkError on darkBackground': (
        AppColors.darkError,
        AppColors.darkBackground,
      ),
    };

    for (final entry in pairs.entries) {
      test(entry.key, () {
        final ratio = contrastRatio(entry.value.$1, entry.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(aaBody),
          reason:
              '${entry.key} is ${ratio.toStringAsFixed(2)}:1, below AA for '
              'body text in dark mode.',
        );
      });
    }

    test('the light theme brand green would be unreadable here', () {
      // Pins the reason darkPrimary exists at all, so nobody "simplifies" the
      // palette back to one green.
      expect(
        contrastRatio(AppColors.primaryDark, AppColors.darkBackground),
        lessThan(aaLarge),
      );
    });
  });

  group('large-text / fill-only colours', () {
    test('primaryGreen on background passes AA large but not body', () {
      final ratio = contrastRatio(
        AppColors.primaryGreen,
        AppColors.background,
      );
      expect(ratio, greaterThanOrEqualTo(aaLarge));
      expect(
        ratio,
        lessThan(aaBody),
        reason:
            'If primaryGreen now passes AA for body text, the '
            'primaryDark-for-buttons workaround can be revisited.',
      );
    });

    test('secondaryGreen is a fill, never text', () {
      expect(
        contrastRatio(AppColors.secondaryGreen, AppColors.background),
        lessThan(aaLarge),
        reason: 'secondaryGreen must stay restricted to fills and borders.',
      );
    });

    test('accentGold is emphasis, never text', () {
      expect(
        contrastRatio(AppColors.accentGold, AppColors.background),
        lessThan(aaLarge),
      );
    });
  });
}
