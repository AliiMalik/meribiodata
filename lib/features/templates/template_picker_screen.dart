import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/core/theme/app_spacing.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/data/bundled_labels.dart';
import 'package:meribiodata/data/profile_repository.dart';
import 'package:meribiodata/domain/render/document_builder.dart';
import 'package:meribiodata/domain/render/template.dart';
import 'package:meribiodata/domain/render/templates.dart';
import 'package:meribiodata/features/ads/rewarded_ads.dart';
import 'package:meribiodata/features/editor/profile_editor_controller.dart';
import 'package:meribiodata/features/export/widgets/document_preview.dart';
import 'package:meribiodata/features/premium/entitlements.dart';
import 'package:meribiodata/features/templates/template_unlocks.dart';
import 'package:meribiodata/features/templates/unlock_sheet.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:provider/provider.dart';

/// §7.5 — visual thumbnails with a live preview of the user's real data.
///
/// The thumbnails are the real renderer at a small scale rather than shipped
/// images, so a template can never look different in the picker from how it
/// exports. Locked templates render at full fidelity too (D19): the user sees
/// their own biodata in the design before deciding whether it is worth an ad.
class TemplatePickerScreen extends StatefulWidget {
  const TemplatePickerScreen({required this.profileId, super.key});

  final String profileId;

  @override
  State<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends State<TemplatePickerScreen> {
  late final ProfileEditorController _controller = ProfileEditorController(
    context.read<ProfileRepository>(),
    widget.profileId,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_controller.load());
    unawaited(context.read<TemplateUnlocks>().load());
    // Fetched now rather than when the sheet opens, so tapping a locked
    // template usually shows an ad immediately instead of a spinner.
    context.read<RewardedAds>().warmUp();
  }

  @override
  void dispose() {
    unawaited(_controller.flush());
    _controller.dispose();
    super.dispose();
  }

  Future<void> _select(DocumentTemplate template) async {
    // `_controller` directly, never context.read<ProfileEditorController>().
    // That provider is created inside this widget's own build(), so the State's
    // context sits *above* it and the read throws ProviderNotFoundException —
    // which, in an async callback in a release build, is swallowed with no
    // visible effect. Every tap silently did nothing, and locked templates
    // never reached the unlock sheet.
    final unlocks = context.read<TemplateUnlocks>();
    final isPremium = context.read<Entitlements>().isPremium;

    if (canUseTemplate(template, isPremium: isPremium, unlocks: unlocks)) {
      _controller.setTemplate(template.id);
      return;
    }

    final unlocked = await showTemplateUnlockSheet(context, template);
    // Selecting only after a successful unlock. Selecting first and unlocking
    // afterwards would leave the profile pointing at a template it cannot
    // export if the ad is abandoned.
    if (unlocked) _controller.setTemplate(template.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final labels = context.watch<BundledLabels>();

    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ProfileEditorController>(
        builder: (context, controller, _) {
          final profile = controller.profile;
          if (profile == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final document = DocumentBuilder(
            labels: labels,
            stringsFor: labels.stringsFor,
            units: context.watch<AppPreferences>().documentUnits,
          ).build(profile);
          final selected = profile.templateId ?? Templates.defaultId;

          // Watched, not read: buying Premium or finishing an ad must make the
          // locks fall away without leaving and re-entering the screen.
          final isPremium = context.watch<Entitlements>().isPremium;
          final unlocks = context.watch<TemplateUnlocks>();

          return Scaffold(
            appBar: AppBar(title: Text(l10n.templatePickerTitle)),
            // The picker is now a step on the way to export rather than a
            // detour off the editor (D19), so it needs a way onward of its own.
            bottomNavigationBar: Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await controller.flush();
                        if (context.mounted) {
                          await context.push(
                            AppRoutes.exportFor(profile.id),
                          );
                        }
                        await controller.load();
                      },
                      icon: const Icon(Icons.visibility_outlined),
                      label: Text(l10n.exportTitle),
                    ),
                  ),
                ),
              ),
            ),
            // Slivers rather than a ListView of shrink-wrapped grids. A
            // shrink-wrapped grid lays out every child to measure itself, so
            // the old version rendered all seventeen biodatas at once — fine
            // at four templates, an NFR-2 problem at seventeen. A SliverGrid
            // builds only what is on screen.
            body: CustomScrollView(
              slivers: [
                for (final category in TemplateCategory.values)
                  if (Templates.inCategory(category) case final templates
                      when templates.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          _categoryName(l10n, category),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.62,
                              mainAxisSpacing: AppSpacing.lg,
                              crossAxisSpacing: AppSpacing.lg,
                            ),
                        itemCount: templates.length,
                        itemBuilder: (context, index) {
                          final template = templates[index];
                          return _TemplateCard(
                            template: template,
                            isSelected: template.id == selected,
                            usable: canUseTemplate(
                              template,
                              isPremium: isPremium,
                              unlocks: unlocks,
                            ),
                            hoursLeft: unlocks
                                .remainingFor(template.id)
                                ?.inHours,
                            preview: DocumentPreview(
                              document: document,
                              template: template,
                              page: PageSpec.a4,
                              maxWidth: 150,
                            ),
                            onTap: () => _select(template),
                          );
                        },
                      ),
                    ),
                  ],

                // The way out of watching ads, where the locks are.
                if (!isPremium)
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => context.push(AppRoutes.premium),
                          icon: const Icon(Icons.workspace_premium_outlined),
                          label: Text(l10n.templateUnlockPremium),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _categoryName(AppL10n l10n, TemplateCategory category) =>
      switch (category) {
        TemplateCategory.standard => l10n.templateCategoryStandard,
        TemplateCategory.classic => l10n.templateCategoryClassic,
        TemplateCategory.creative => l10n.templateCategoryCreative,
        TemplateCategory.thematic => l10n.templateCategoryThematic,
        TemplateCategory.geometric => l10n.templateCategoryGeometric,
        TemplateCategory.religious => l10n.templateCategoryReligious,
      };
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.isSelected,
    required this.usable,
    required this.hoursLeft,
    required this.preview,
    required this.onTap,
  });

  final DocumentTemplate template;
  final bool isSelected;
  final bool usable;
  final int? hoursLeft;
  final Widget preview;
  final VoidCallback onTap;

  /// Two lines of name plus one of subtitle, whether or not this card uses
  /// them. Reserving the space is what keeps the row aligned.
  ///
  /// Measured, not guessed: 62 overflowed by exactly 2px on a two-line name
  /// with a subtitle, which a widget test caught immediately.
  static const _labelHeight = 68.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: isSelected
                ? context.colors.primary
                : context.colors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? context.colors.primaryContainer : null,
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // RepaintBoundary: each preview is a fully laid-out A4
                  // document, so without this a selection change repaints
                  // every visible thumbnail rather than the two that altered.
                  // Never dimmed or blurred: the design is the thing being
                  // sold, so it has to be visible to be wanted.
                  RepaintBoundary(child: Center(child: preview)),
                  if (!usable)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: context.semantics.badge,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock,
                          size: 16,
                          color: context.semantics.onBadge,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Fixed height, so every thumbnail in a row starts at the same
            // point. Without it the label block sets the size of the Expanded
            // above, and a two-line name or a "Locked" subtitle pushes that
            // card's preview visibly out of line with its neighbour's.
            SizedBox(
              height: _labelHeight,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected) ...[
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: context.colors.onPrimaryContainer,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Flexible(
                        // A selected card is filled, so its label takes the
                        // fill's "on" colour; an unselected one sits on the
                        // page and keeps the ordinary body colour.
                        child: Text(
                          template.name,
                          style: text.titleMedium?.copyWith(
                            color: isSelected
                                ? context.colors.onPrimaryContainer
                                : null,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (!usable)
                    Text(
                      l10n.templateLocked,
                      style: text.bodySmall?.copyWith(
                        color: isSelected
                            ? context.colors.onPrimaryContainer
                            : null,
                      ),
                      textAlign: TextAlign.center,
                    )
                  // Shown only for an ad-unlock, which runs out. Premium and
                  // free templates have nothing to count down.
                  else if (hoursLeft case final int hours)
                    Text(
                      l10n.templateUnlockedHoursLeft(hours),
                      style: text.bodySmall?.copyWith(
                        color: isSelected
                            ? context.colors.onPrimaryContainer
                            : null,
                      ),
                      textAlign: TextAlign.center,
                    )
                  else if (template.isMonochrome)
                    Text(
                      l10n.templateMonochrome,
                      style: text.bodySmall?.copyWith(
                        color: isSelected
                            ? context.colors.onPrimaryContainer
                            : null,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
