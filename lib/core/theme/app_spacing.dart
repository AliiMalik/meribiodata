import 'package:flutter/widgets.dart';

/// Spacing, radius and sizing tokens. No widget may hard-code these numbers.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Standard horizontal page gutter.
  static const pageGutter = 16.0;

  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;

  /// Minimum interactive size. The primary user is often a parent in their
  /// 50s or 60s (build prompt §9.7), so this sits above Material's 48dp floor
  /// for the app's own controls.
  static const minTapTarget = 48.0;

  static const insetsPage = EdgeInsets.symmetric(horizontal: pageGutter);
  static const insetsCard = EdgeInsets.all(lg);
}
