/// Unicode bidi isolation for values rendered inside an RTL document.
///
/// M0 finding: `+92 300 1234567` renders as `1234567 300 92+` inside an Urdu
/// paragraph — in Flutter *and* in Blink, because that is correct Unicode bidi.
/// The digit groups are separate left-to-right runs and the spaces between them
/// are neutral, so they take the paragraph's right-to-left direction and the
/// groups come out reversed.
///
/// The fix is to mark such runs as their own left-to-right island using
/// isolate characters. See `docs/spike-nastaliq.md`.
abstract final class BidiText {
  /// U+2066 LEFT-TO-RIGHT ISOLATE — forces LTR inside, isolated from outside.
  ///
  /// Built from its code point rather than written as a literal: the character
  /// is invisible and would silently rearrange how this source file reads.
  static final lri = String.fromCharCode(0x2066);

  /// U+2069 POP DIRECTIONAL ISOLATE.
  static final pdi = String.fromCharCode(0x2069);

  /// A run of digits and number punctuation containing at least two separated
  /// groups — phone numbers, dates like `15/03/1995`, amounts like `1,50,000`.
  ///
  /// A single group (`2019`, `12`) is deliberately *not* matched: bidi already
  /// places a lone number correctly, and wrapping it would add invisible
  /// characters to every year in the document for no benefit.
  static final _multiGroupNumber = RegExp(
    r'[+(]?\d+(?:[)\-./  ,]+\d+)+[)]?',
  );

  /// Wraps [value] so it renders left-to-right regardless of the surrounding
  /// paragraph. For values that are entirely numeric — a phone number, a
  /// height, an amount.
  static String isolate(String value) {
    if (value.isEmpty) return value;
    return '$lri$value$pdi';
  }

  /// Wraps only the numeric runs inside otherwise-textual [value].
  ///
  /// Used for free text, which may contain a phone number in the middle of a
  /// sentence — an address, an "additional information" paragraph.
  static String isolateNumericRuns(String value) {
    if (value.isEmpty) return value;
    return value.replaceAllMapped(
      _multiGroupNumber,
      (m) => '$lri${m[0]}$pdi',
    );
  }

  /// Removes isolate characters. Golden tests and any future text extraction
  /// compare against clean strings.
  static String strip(String value) =>
      value.replaceAll(lri, '').replaceAll(pdi, '');
}
