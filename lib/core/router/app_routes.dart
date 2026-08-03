/// Route paths and names. Never write a route string at a call site.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/';
  static const settings = '/settings';

  /// Phase 2 teaser. Captures interest only — no CRM screen may be reachable
  /// from here (build prompt §0.1, §7.8).
  static const matchmakerPro = '/matchmaker-pro';

  static const editor = '/biodata/:id/edit';
  static const schemaEditor = '/biodata/:id/schema';
  static const templatePicker = '/biodata/:id/template';
  static const export = '/biodata/:id/export';

  static String editorFor(String id) => '/biodata/$id/edit';
  static String schemaEditorFor(String id) => '/biodata/$id/schema';
  static String templatePickerFor(String id) => '/biodata/$id/template';
  static String exportFor(String id) => '/biodata/$id/export';
}
