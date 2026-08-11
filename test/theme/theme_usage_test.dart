import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The rule `app_colors.dart` states in its own doc comment, enforced.
///
/// Cover for a bug a user hit: in dark mode several panels were unreadable —
/// a light green fill from the light palette, carrying text the dark theme had
/// coloured near-white. Every pair in `contrast_test.dart` passed the whole
/// time, because that test measures the *palette* and the defect was in how
/// widgets combined it.
///
/// A palette constant names one theme's colour. Using one in a widget picks
/// that theme and is therefore wrong in the other by construction, which no
/// amount of contrast-checking the constants can detect. So the check is
/// structural: widgets go through `Theme.of(context)` — or the `context.colors`
/// / `context.semantics` shorthands — and only the theme layer names colours.
void main() {
  test('only the theme layer names palette constants', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;

      final path = entity.path.replaceAll(r'\', '/');
      // The theme layer is where the palette is allowed to be named — that is
      // its whole job.
      if (path.startsWith('lib/core/theme/')) continue;

      final source = entity.readAsStringSync();
      for (final line in source.split('\n')) {
        if (line.trimLeft().startsWith('//')) continue;
        if (line.contains('AppColors.')) {
          offenders.add('$path: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          "These name a single theme's colour, so the other theme is wrong:\n"
          '${offenders.join('\n')}\n\n'
          'Use Theme.of(context).colorScheme (or context.colors), and for a '
          'role Material has no slot for, context.semantics.',
    );
  });

  test('the document renderer is exempt, and stays separate', () {
    // A biodata is printed and forwarded, so it is always dark ink on white
    // paper whatever the app's theme is. That is TemplateStyle's job, and it
    // deliberately does not go through the app theme (§10) — which is why the
    // check above does not sweep it up.
    final style = File('lib/domain/render/template.dart');
    expect(style.existsSync(), isTrue);
    expect(
      style.readAsStringSync().contains('AppColors.'),
      isFalse,
      reason: 'the document palette must not be the app palette',
    );
  });
}
