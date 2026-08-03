import 'package:flutter/material.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';

/// Stands in for a screen that a later milestone will build.
///
/// Deliberately unmistakable: routing plumbing is real from M1 onward, so a
/// route must never silently render an empty page that looks finished.
class MilestonePlaceholder extends StatelessWidget {
  const MilestonePlaceholder({
    required this.title,
    required this.milestone,
    required this.summary,
    super.key,
  });

  final String title;

  /// e.g. `'M3'`.
  final String milestone;

  /// What this screen will do, in one line.
  final String summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Text(
                  '$milestone — not built yet',
                  style: text.labelLarge?.copyWith(
                    color: AppColors.onLightGreen,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                summary,
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
