import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_colors.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/widgets/text_prompt_dialog.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/biodata/biodata_profile.dart';
import 'package:meribiodata/features/ads/banner_slot.dart';
import 'package:meribiodata/features/ads/interstitial_ads.dart';
import 'package:meribiodata/features/home/profile_list_controller.dart';
import 'package:meribiodata/features/premium/entitlements.dart';
import 'package:meribiodata/features/premium/premium_prompts.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// The list of saved biodata profiles (§7.2).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ProfileListController _controller = ProfileListController(
    context.read<ProfileRepository>(),
  )..load();

  @override
  void initState() {
    super.initState();
    // After the first frame: this pushes a route, which cannot happen while the
    // widget is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptPremium());
  }

  /// Opens Premium by itself at most once a week, and never for somebody who
  /// has already paid (D17).
  Future<void> _maybePromptPremium() async {
    final prompts = context.read<PremiumPrompts>();
    await prompts.load();
    if (!mounted) return;
    if (context.read<Entitlements>().isPremium) return;
    if (!prompts.canPromptAtLaunch) return;

    await prompts.recordPrompt();
    if (!mounted) return;
    await context.push(AppRoutes.premium);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final language = context.read<AppPreferences>().uiLanguage;
    final interstitials = context.read<InterstitialAds>();
    // A new biodata defaults to the language the user reads the app in — the
    // most likely choice, and changeable per profile afterwards (§5).
    final profile = await _controller.createProfile(
      documentLanguageCode: language.availableAsDocumentLanguage
          ? language.code
          : 'en',
    );

    // Saved first, ad second. If the ad were shown before the profile existed,
    // a user who force-closed the app during it would lose the tap entirely —
    // and an interstitial is a plausible moment to force-close. This way the
    // biodata is already on disk before anything full-screen appears.
    //
    // Returns immediately unless an ad is genuinely due and ready (#30).
    await interstitials.onCreateBiodata();

    if (!mounted) return;
    await context.push(AppRoutes.editorFor(profile.id));
    // The editor autosaves, so what is on screen here is stale the moment it
    // pops. Without this the list keeps showing "Untitled biodata, 0%" after
    // the user has just filled the form in.
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return ChangeNotifierProvider.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.navHome),
          actions: [
            IconButton(
              onPressed: () => context.push(AppRoutes.premium),
              icon: const Icon(Icons.workspace_premium_outlined),
              tooltip: l10n.premiumTitle,
            ),
            IconButton(
              onPressed: () => context.push(AppRoutes.settings),
              icon: const Icon(Icons.settings_outlined),
              tooltip: l10n.navSettings,
            ),
          ],
        ),
        floatingActionButton: Consumer<ProfileListController>(
          builder: (context, controller, _) => controller.isEmpty
              ? const SizedBox.shrink()
              : FloatingActionButton.extended(
                  onPressed: _create,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.homeCreate),
                ),
        ),
        body: Column(
          children: [
            const _PremiumCard(),
            Expanded(
              child: Consumer<ProfileListController>(
                builder: (context, controller, _) =>
                    switch (controller.status) {
                      ListStatus.loading => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      ListStatus.failed => Center(
                        child: Text(l10n.errorStorageBody),
                      ),
                      ListStatus.ready when controller.isEmpty => _EmptyState(
                        onCreate: _create,
                      ),
                      ListStatus.ready => _ProfileList(controller: controller),
                    },
              ),
            ),
          ],
        ),
        // Reserved layout space, not an overlay (§8). Collapses to nothing when
        // there is no consent, no fill or no network.
        bottomNavigationBar: const BannerSlot(screenId: 'home'),
      ),
    );
  }
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({required this.controller});

  final ProfileListController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final profiles = controller.visible;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: TextField(
            onChanged: controller.search,
            decoration: InputDecoration(
              hintText: l10n.homeSearch,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
        if (profiles.isEmpty)
          Expanded(child: Center(child: Text(l10n.homeNoMatches)))
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                // Clear of the FAB.
                AppSpacing.xxl * 2,
              ),
              itemCount: profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _ProfileCard(
                profile: profiles[index],
                controller: controller,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.controller});

  final BiodataProfile profile;
  final ProfileListController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final name = profileDisplayName(profile, l10n.editorUntitled);
    final percent = (profile.completion * 100).round();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () async {
          await context.push(AppRoutes.editorFor(profile.id));
          await controller.load();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${l10n.editorProgress(percent)}  ·  '
                      '${l10n.homeUpdatedAt(_shortDate(profile.updatedAt))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: profile.completion,
                        minHeight: 4,
                        backgroundColor: AppColors.divider,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_CardAction>(
                icon: const Icon(Icons.more_vert),
                onSelected: (action) => _handle(context, action),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _CardAction.duplicate,
                    child: Text(l10n.homeDuplicate),
                  ),
                  PopupMenuItem(
                    value: _CardAction.delete,
                    child: Text(l10n.actionDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, _CardAction action) async {
    final l10n = AppL10n.of(context);
    final name = profileDisplayName(profile, l10n.editorUntitled);

    switch (action) {
      case _CardAction.duplicate:
        await controller.duplicateProfile(profile, l10n.homeCopySuffix(name));
      case _CardAction.delete:
        // Deleting a biodata someone spent ten minutes on is worth a
        // confirmation, and it is irreversible — there is no server copy.
        final confirmed = await confirm(
          context,
          title: l10n.homeDeleteTitle,
          body: l10n.homeDeleteBody(name),
          confirmLabel: l10n.actionDelete,
          isDestructive: true,
        );
        if (confirmed) await controller.deleteProfile(profile.id);
    }
  }

  static String _shortDate(DateTime at) => '${at.day}/${at.month}/${at.year}';
}

enum _CardAction { duplicate, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;

    return Center(
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
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text(l10n.homeCreate),
            ),
          ],
        ),
      ),
    );
  }
}

/// The permanent, dismissible Premium upsell (D17).
///
/// A card in the layout rather than a dialog or a launch interstitial: it is
/// always visible, never blocks anything, and goes away for good when sent
/// away. It is the trade that replaced replaying the onboarding carousel on
/// every launch.
class _PremiumCard extends StatelessWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;

    final isPremium = context.select<Entitlements, bool>((e) => e.isPremium);
    final show = context.select<PremiumPrompts, bool>((p) => p.showCard);
    if (isPremium || !show) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      child: Card(
        color: AppColors.secondaryGreen.withValues(alpha: 0.10),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: () => context.push(AppRoutes.premium),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.premiumCardTitle, style: text.titleSmall),
                      Text(l10n.premiumCardBody, style: text.bodySmall),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      unawaited(context.read<PremiumPrompts>().dismissCard()),
                  child: Text(l10n.premiumCardDismiss),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
