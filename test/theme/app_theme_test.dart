import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';

void main() {
  group('typography follows the UI locale', () {
    test('Latin locales use Inter with default leading', () {
      final theme = AppTheme.lightFor(AppLanguages.english);

      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.bodyMedium?.height, isNull);
    });

    test('Urdu uses the bundled Nastaliq face, not a system fallback', () {
      final theme = AppTheme.lightFor(AppLanguages.urdu);

      expect(theme.textTheme.bodyMedium?.fontFamily, 'NotoNastaliqUrdu');
      expect(
        theme.textTheme.bodyMedium?.fontFamilyFallback,
        containsAllInOrder(<String>['NotoNaskhArabic', 'Inter']),
        reason:
            'Nastaliq needs a Naskh fallback for glyphs it lacks, and '
            'Inter for Latin runs inside RTL chrome.',
      );
    });

    test('Nastaliq chrome gets extra leading so letter-stacks do not clip', () {
      final urdu = AppTheme.lightFor(AppLanguages.urdu);
      final height = urdu.textTheme.bodyMedium?.height;

      expect(height, isNotNull);
      expect(height, greaterThan(1.4));
    });
  });

  group('component defaults respect the contrast rules', () {
    test('filled buttons use primaryDark, not primaryGreen', () {
      final theme = AppTheme.lightFor(AppLanguages.english);
      final background = theme.filledButtonTheme.style?.backgroundColor
          ?.resolve({});

      expect(
        background,
        AppColors.primaryDark,
        reason:
            'White on primaryGreen is 3.30:1 — below AA for a button '
            'label. See test/theme/contrast_test.dart.',
      );
    });

    test('interactive defaults meet the 48dp minimum tap target', () {
      final theme = AppTheme.lightFor(AppLanguages.english);
      final size = theme.filledButtonTheme.style?.minimumSize?.resolve({});

      expect(size?.height, greaterThanOrEqualTo(48));
    });
  });
}
