import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/router/app_router.dart';
import 'package:meribiodata/core/storage/local_store.dart';
import 'package:meribiodata/core/theme/app_theme.dart';
import 'package:meribiodata/l10n/generated/app_localizations.dart';
import 'package:meribiodata/l10n/language_descriptor.dart';
import 'package:provider/provider.dart';

class MeriBiodataApp extends StatefulWidget {
  const MeriBiodataApp({
    required this.store,
    required this.preferences,
    super.key,
  });

  final LocalStore store;
  final AppPreferences preferences;

  @override
  State<MeriBiodataApp> createState() => _MeriBiodataAppState();
}

class _MeriBiodataAppState extends State<MeriBiodataApp> {
  late final GoRouter _router = buildRouter(widget.preferences);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<LocalStore>.value(value: widget.store),
        ChangeNotifierProvider<AppPreferences>.value(
          value: widget.preferences,
        ),
      ],
      child: Consumer<AppPreferences>(
        builder: (context, preferences, _) => MaterialApp.router(
          onGenerateTitle: (context) => AppL10n.of(context).appName,
          theme: AppTheme.lightFor(preferences.uiLanguage),
          routerConfig: _router,
          locale: Locale(preferences.uiLanguage.code),
          supportedLocales: [
            for (final language in AppLanguages.uiLocales)
              Locale(language.code),
          ],
          localizationsDelegates: AppL10n.localizationsDelegates,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

/// Shown when the encrypted store cannot be opened. Deliberately standalone —
/// it must not depend on anything that failed to initialise.
class StorageFailureApp extends StatelessWidget {
  const StorageFailureApp({required this.onRetry, super.key});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.lightFor(AppLanguages.english),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: [
        for (final language in AppLanguages.uiLocales) Locale(language.code),
      ],
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          final l10n = AppL10n.of(context);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      l10n.errorGenericTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.errorStorageBody,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: onRetry,
                      child: Text(l10n.actionRetry),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
