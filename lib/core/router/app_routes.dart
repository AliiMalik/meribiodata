/// Route paths and names. Never write a route string at a call site.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const home = '/';
  static const settings = '/settings';
  static const sync = '/settings/backup';

  /// Where ads and the export watermark are bought away (D17). Took the place
  /// of the Matchmaker Pro waitlist, which was withdrawn.
  static const premium = '/premium';

  static const editor = '/biodata/:id/edit';
  static const schemaEditor = '/biodata/:id/schema';
  static const templatePicker = '/biodata/:id/template';
  static const export = '/biodata/:id/export';

  static String editorFor(String id) => '/biodata/$id/edit';
  static String schemaEditorFor(String id) => '/biodata/$id/schema';
  static String templatePickerFor(String id) => '/biodata/$id/template';
  static String exportFor(String id) => '/biodata/$id/export';
}
