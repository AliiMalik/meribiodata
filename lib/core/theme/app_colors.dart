import 'package:flutter/material.dart';

/// The only file in the app allowed to contain a raw colour literal.
///
/// Widgets must go through `AppTheme` / `Theme.of(context)` or the semantic
/// aliases below — never through a hex value inline.
///
/// Every pairing used by the app is contrast-checked in
/// `test/theme/contrast_test.dart`, which fails CI if a change drops a
/// text-on-surface pair below WCAG AA.
abstract final class AppColors {
  // --- Core palette (build prompt §10) ---------------------------------

  /// Brand green. Passes AA only as *large* text (>= 18.66px bold) on white,
  /// so it is used for fills, active states and selection — not for button
  /// labels. See [primaryDark] for text-bearing containers.
  static const primaryGreen = Color(0xFF16A34A);

  /// Pressed state, navigation bar, headings — and the container colour for
  /// filled buttons, because white-on-[primaryGreen] is only 3.30:1.
  static const primaryDark = Color(0xFF166534);

  /// Cards, subtle highlights. Fills, borders and large text only (1.82:1 on
  /// the app background — never body text).
  static const secondaryGreen = Color(0xFF84CC96);

  /// Success backgrounds, badges, notification panels.
  static const lightGreen = Color(0xFFDCFCE7);

  /// Icons, links, selected tabs.
  static const accentTeal = Color(0xFF0F766E);

  /// Premium badges, achievements, subtle emphasis. 2.27:1 on background —
  /// emphasis and ornament only, never text.
  static const accentGold = Color(0xFFD4A017);

  static const background = Color(0xFFFAFAF9);
  static const surface = Color(0xFFF1F5F9);

  static const textPrimary = Color(0xFF1F2937);

  /// Slate-600 rather than the Slate-500 (`#64748B`) named in the build prompt.
  /// `#64748B` measures 4.34:1 on [surface] — below AA for body text — which
  /// would fail on every card and input field in the app. See
  /// `docs/decisions.md` D5.
  static const textSecondary = Color(0xFF475569);

  // --- Supporting ------------------------------------------------------

  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFDC2626);
  static const divider = Color(0xFFE5E7EB);

  static const white = Color(0xFFFFFFFF);

  // --- Semantic "on" colours -------------------------------------------
  // The bright fills all carry dark text: white on success/warning/gold
  // measures 2.1-2.4:1 and is unreadable.

  static const Color onPrimary = white;
  static const Color onSuccess = textPrimary;
  static const Color onWarning = textPrimary;
  static const Color onError = white;
  static const Color onAccentGold = textPrimary;
  static const Color onSecondaryGreen = textPrimary;
  static const Color onLightGreen = textPrimary;
}
