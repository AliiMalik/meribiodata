import 'package:go_router/go_router.dart';
import 'package:meribiodata/core/preferences/app_preferences.dart';
import 'package:meribiodata/core/router/app_routes.dart';
import 'package:meribiodata/features/backup/backup_screen.dart';
import 'package:meribiodata/features/editor/editor_screen.dart';
import 'package:meribiodata/features/export/export_screen.dart';
import 'package:meribiodata/features/home/home_screen.dart';
import 'package:meribiodata/features/onboarding/onboarding_screen.dart';
import 'package:meribiodata/features/schema/schema_editor_screen.dart';
import 'package:meribiodata/features/settings/settings_screen.dart';
import 'package:meribiodata/features/templates/template_picker_screen.dart';
import 'package:meribiodata/features/waitlist/waitlist_screen.dart';

/// Builds the app router.
///
/// [preferences] is passed as a `refreshListenable` so completing onboarding
/// re-evaluates the redirect without any imperative navigation.
GoRouter buildRouter(AppPreferences preferences) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: preferences,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!preferences.onboardingComplete && !atOnboarding) {
        return AppRoutes.onboarding;
      }
      if (preferences.onboardingComplete && atOnboarding) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.backup,
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: AppRoutes.matchmakerPro,
        builder: (context, state) => const WaitlistScreen(),
      ),
      GoRoute(
        path: AppRoutes.editor,
        builder: (context, state) =>
            EditorScreen(profileId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.schemaEditor,
        builder: (context, state) =>
            SchemaEditorScreen(profileId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.templatePicker,
        builder: (context, state) =>
            TemplatePickerScreen(profileId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.export,
        builder: (context, state) =>
            ExportScreen(profileId: state.pathParameters['id']!),
      ),
    ],
  );
}
