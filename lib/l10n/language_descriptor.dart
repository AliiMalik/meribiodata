import 'dart:ui' show TextDirection;

/// Script family. Drives font selection, line-height, and — per
/// `docs/decisions.md` D1 — which PDF pipeline renders the document.
enum TextScript { latin, nastaliq, naskh }

/// Which rendering pipeline a document in this script uses (D1).
enum RenderPipeline {
  /// `pdf` package vector text. Correct and compact for Latin only.
  vector,

  /// Flutter widget tree captured from a `RepaintBoundary`. The only pipeline
  /// that renders Perso-Arabic correctly.
  raster,
}

/// Western (0-9) vs Eastern Arabic (٠-٩) numerals. Urdu documents use either,
/// so it is a user preference with a sensible per-language default (§5).
enum DigitStyle { western, easternArabic }

/// Launch priority (§5). P0+P1 ship in v1.0 — see `docs/decisions.md` D3.
enum LanguagePriority { p0, p1, p2 }

/// Everything the app needs to know about a language.
///
/// Adding a language must be a **data-only** change: one entry here plus an ARB
/// file. If a change requires touching rendering or layout code, the
/// abstraction is wrong.
class LanguageDescriptor {
  const LanguageDescriptor({
    required this.code,
    required this.englishName,
    required this.nativeName,
    required this.script,
    required this.priority,
    required this.hasUiTranslation,
    required this.availableAsDocumentLanguage,
    this.defaultDigits = DigitStyle.western,
  });

  /// BCP 47 code. Also the ARB suffix (`app_ur.arb`) and the
  /// label-override key.
  final String code;

  final String englishName;

  /// Shown in the language picker, always in the language's own script.
  final String nativeName;

  final TextScript script;
  final LanguagePriority priority;

  /// True once a human-reviewed ARB file ships for this locale.
  final bool hasUiTranslation;

  /// Roman Urdu is a UI locale only — biodatas are formal documents (§5).
  final bool availableAsDocumentLanguage;

  final DigitStyle defaultDigits;

  TextDirection get direction =>
      script == TextScript.latin ? TextDirection.ltr : TextDirection.rtl;

  bool get isRtl => direction == TextDirection.rtl;

  RenderPipeline get pipeline => script == TextScript.latin
      ? RenderPipeline.vector
      : RenderPipeline.raster;

  /// Document font family. Nastaliq falls back to Naskh for glyphs it lacks.
  String get documentFontFamily => switch (script) {
    TextScript.latin => 'Inter',
    TextScript.nastaliq => 'NotoNastaliqUrdu',
    TextScript.naskh => 'NotoNaskhArabic',
  };

  /// Fallback chain for document text.
  ///
  /// Every Perso-Arabic chain ends in Inter, and that is not cosmetic: Noto
  /// Naskh Arabic ships no glyphs for `/ ( ) - +`, which are exactly the
  /// characters a phone number, a date and a parenthesised age need. Without
  /// an explicit fallback those come from whatever font the device happens to
  /// have — the same device-dependent rendering the UI font chain fixes, and
  /// the thing this product cannot afford to get wrong.
  List<String> get documentFontFallback => switch (script) {
    TextScript.latin => const [],
    TextScript.nastaliq => const ['NotoNaskhArabic', 'Inter'],
    TextScript.naskh => const ['Inter'],
  };

  /// Line-height multiplier for *document* text blocks.
  ///
  /// Nastaliq stacks letters vertically and drops long descenders; the Latin
  /// default of 1.4 makes them collide. Measured in M0 — see
  /// `docs/spike-nastaliq.md`.
  double get lineHeight => switch (script) {
    TextScript.latin => 1.4,
    TextScript.nastaliq => 2.1,
    TextScript.naskh => 1.7,
  };

  /// Line-height multiplier for *UI chrome*.
  ///
  /// Lower than [lineHeight] because app labels are mostly one or two lines,
  /// where the full document leading looks unreasonably airy — but still well
  /// above the Latin default, which clips Nastaliq letter-stacks.
  double? get uiLineHeight => switch (script) {
    TextScript.latin => null,
    TextScript.nastaliq => 1.9,
    TextScript.naskh => 1.5,
  };

  /// UI font family. Latin chrome uses Inter; RTL locales use the bundled Noto
  /// face so the interface renders identically on every device instead of
  /// inheriting whatever Urdu font the phone happens to ship.
  String get uiFontFamily =>
      script == TextScript.latin ? 'Inter' : documentFontFamily;

  /// Latin runs inside an RTL interface (numbers, "PDF", "WhatsApp") still
  /// need Inter, and Nastaliq still needs the Naskh fallback.
  List<String> get uiFontFallback => switch (script) {
    TextScript.latin => const [],
    TextScript.nastaliq => const ['NotoNaskhArabic', 'Inter'],
    TextScript.naskh => const ['Inter'],
  };
}

/// The language registry. Order is the order shown in pickers.
abstract final class AppLanguages {
  static const english = LanguageDescriptor(
    code: 'en',
    englishName: 'English',
    nativeName: 'English',
    script: TextScript.latin,
    priority: LanguagePriority.p0,
    hasUiTranslation: true,
    availableAsDocumentLanguage: true,
  );

  static const urdu = LanguageDescriptor(
    code: 'ur',
    englishName: 'Urdu',
    nativeName: 'اردو',
    script: TextScript.nastaliq,
    priority: LanguagePriority.p0,
    hasUiTranslation: true,
    availableAsDocumentLanguage: true,
  );

  static const romanUrdu = LanguageDescriptor(
    code: 'ur_Latn',
    englishName: 'Roman Urdu',
    nativeName: 'Roman Urdu',
    script: TextScript.latin,
    priority: LanguagePriority.p1,
    hasUiTranslation: false,
    availableAsDocumentLanguage: false,
  );

  static const sindhi = LanguageDescriptor(
    code: 'sd',
    englishName: 'Sindhi',
    nativeName: 'سنڌي',
    script: TextScript.naskh,
    priority: LanguagePriority.p1,
    hasUiTranslation: false,
    availableAsDocumentLanguage: true,
  );

  static const pashto = LanguageDescriptor(
    code: 'ps',
    englishName: 'Pashto',
    nativeName: 'پښتو',
    script: TextScript.naskh,
    priority: LanguagePriority.p1,
    hasUiTranslation: false,
    availableAsDocumentLanguage: true,
  );

  static const punjabi = LanguageDescriptor(
    code: 'pa_Arab',
    englishName: 'Punjabi (Shahmukhi)',
    nativeName: 'پنجابی',
    script: TextScript.nastaliq,
    priority: LanguagePriority.p1,
    hasUiTranslation: false,
    availableAsDocumentLanguage: true,
  );

  static const saraiki = LanguageDescriptor(
    code: 'skr',
    englishName: 'Saraiki',
    nativeName: 'سرائیکی',
    script: TextScript.nastaliq,
    priority: LanguagePriority.p2,
    hasUiTranslation: false,
    availableAsDocumentLanguage: true,
  );

  static const balochi = LanguageDescriptor(
    code: 'bal',
    englishName: 'Balochi',
    nativeName: 'بلوچی',
    script: TextScript.naskh,
    priority: LanguagePriority.p2,
    hasUiTranslation: false,
    availableAsDocumentLanguage: true,
  );

  static const hindko = LanguageDescriptor(
    code: 'hno',
    englishName: 'Hindko',
    nativeName: 'ہندکو',
    script: TextScript.nastaliq,
    priority: LanguagePriority.p2,
    hasUiTranslation: false,
    availableAsDocumentLanguage: true,
  );

  static const brahui = LanguageDescriptor(
    code: 'brh',
    englishName: 'Brahui',
    nativeName: 'براہوئی',
    script: TextScript.naskh,
    priority: LanguagePriority.p2,
    hasUiTranslation: false,
    availableAsDocumentLanguage: true,
  );

  static const kashmiri = LanguageDescriptor(
    code: 'ks',
    englishName: 'Kashmiri',
    nativeName: 'کٲشُر',
    script: TextScript.naskh,
    priority: LanguagePriority.p2,
    hasUiTranslation: false,
    availableAsDocumentLanguage: true,
  );

  static const arabic = LanguageDescriptor(
    code: 'ar',
    englishName: 'Arabic',
    nativeName: 'العربية',
    script: TextScript.naskh,
    priority: LanguagePriority.p2,
    hasUiTranslation: false,
    availableAsDocumentLanguage: true,
    defaultDigits: DigitStyle.easternArabic,
  );

  static const all = <LanguageDescriptor>[
    english,
    urdu,
    romanUrdu,
    sindhi,
    pashto,
    punjabi,
    saraiki,
    balochi,
    hindko,
    brahui,
    kashmiri,
    arabic,
  ];

  /// Languages the *interface* can currently be shown in.
  static List<LanguageDescriptor> get uiLocales =>
      all.where((l) => l.hasUiTranslation).toList();

  /// Languages a *biodata document* can be generated in.
  static List<LanguageDescriptor> get documentLanguages =>
      all.where((l) => l.availableAsDocumentLanguage).toList();

  static LanguageDescriptor byCode(String code) =>
      all.firstWhere((l) => l.code == code, orElse: () => english);
}
