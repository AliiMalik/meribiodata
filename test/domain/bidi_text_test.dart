import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/domain/text/bidi_text.dart';

void main() {
  group('whole-value isolation', () {
    test('wraps a value so it cannot reverse in an RTL paragraph', () {
      final isolated = BidiText.isolate('+92 300 1234567');

      expect(isolated.startsWith(BidiText.lri), isTrue);
      expect(isolated.endsWith(BidiText.pdi), isTrue);
      expect(BidiText.strip(isolated), '+92 300 1234567');
    });

    test('leaves an empty value alone rather than emitting two marks', () {
      expect(BidiText.isolate(''), '');
    });
  });

  group('numeric runs inside text', () {
    // The M0 regression: this exact string rendered as "1234567 300 92+"
    // inside an Urdu paragraph, in Flutter and in Blink.
    test('isolates a phone number embedded in Urdu prose', () {
      const sentence = 'رابطے کے لیے +92 300 1234567 پر کال کریں۔';

      final result = BidiText.isolateNumericRuns(sentence);

      expect(result, contains('${BidiText.lri}+92 300 1234567${BidiText.pdi}'));
      expect(BidiText.strip(result), sentence);
    });

    test('isolates a date written with separators', () {
      final result = BidiText.isolateNumericRuns('15/03/1995');
      expect(result, '${BidiText.lri}15/03/1995${BidiText.pdi}');
    });

    test('isolates a grouped amount', () {
      final result = BidiText.isolateNumericRuns('1,50,000');
      expect(result, '${BidiText.lri}1,50,000${BidiText.pdi}');
    });

    test('leaves a lone number alone', () {
      // Bidi already places a single run correctly. Wrapping every year in the
      // document would add invisible characters for no benefit.
      const sentence = 'میں نے 2019 میں MBBS مکمل کیا';

      expect(BidiText.isolateNumericRuns(sentence), sentence);
    });

    test('isolates several runs in one sentence independently', () {
      const sentence = 'پیدائش 15/03/1995، فون +92 300 1234567';

      final result = BidiText.isolateNumericRuns(sentence);

      expect(result.split(BidiText.lri).length - 1, 2);
      expect(BidiText.strip(result), sentence);
    });

    test('a single group with a letter suffix is left alone', () {
      // "12-B" is one group, not two numbers, so bidi already places it.
      const sentence = 'گھر 12-B';
      expect(BidiText.isolateNumericRuns(sentence), sentence);
    });

    test('leaves pure text untouched', () {
      const sentence = 'محمد علی ملک';
      expect(BidiText.isolateNumericRuns(sentence), sentence);
    });
  });

  test('strip is the exact inverse of both isolators', () {
    const values = ['+92 300 1234567', '15/03/1995', 'ڈاکٹر، لاہور', ''];

    for (final value in values) {
      expect(BidiText.strip(BidiText.isolate(value)), value, reason: value);
      expect(
        BidiText.strip(BidiText.isolateNumericRuns(value)),
        value,
        reason: value,
      );
    }
  });
}
