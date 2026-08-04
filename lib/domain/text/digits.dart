import 'package:meribiodata/l10n/language_descriptor.dart';

/// Western (0-9) ↔ Eastern Arabic (٠-٩) numerals.
///
/// Urdu documents use either and getting it wrong looks off (§5), so it is a
/// user preference applied at render time — never at storage time, because the
/// same profile can be exported in two languages.
abstract final class Digits {
  static const _eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  static String format(String value, DigitStyle style) => switch (style) {
    DigitStyle.western => value,
    DigitStyle.easternArabic => _toEastern(value),
  };

  static String _toEastern(String value) {
    final buffer = StringBuffer();
    for (final unit in value.codeUnits) {
      final digit = unit - 0x30;
      buffer.write(
        digit >= 0 && digit <= 9 ? _eastern[digit] : String.fromCharCode(unit),
      );
    }
    return buffer.toString();
  }
}
