import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';

/// The list of saved biodata profiles (§7.2).
///
/// M1 ships the shell and the empty state; the profile list, search, duplicate
/// and delete land in M2 once the profile model exists.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navHome),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.matchmakerPro),
            icon: const Icon(Icons.workspace_premium_outlined),
            tooltip: l10n.waitlistTitle,
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.navSettings,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 64,
                color: AppColors.secondaryGreen,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.homeEmptyTitle,
                style: text.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.homeEmptyBody,
                style: text.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => context.push(AppRoutes.editorFor('new')),
                icon: const Icon(Icons.add),
                label: Text(l10n.homeCreate),
              ),
            ],
          ),
        ),
      ),
      // The anchored adaptive banner (§8) is reserved layout space on Home and
      // the Form Editor only, and is wired in M4.
    );
  }
}
