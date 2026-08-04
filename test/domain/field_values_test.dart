import 'package:flutter_test/flutter_test.dart';
import 'package:meribiodata/domain/biodata/field_type.dart';
import 'package:meribiodata/domain/biodata/field_values.dart';
import 'package:meribiodata/domain/biodata/validation_rule.dart';

void main() {
  group('height stores centimetres canonically', () {
    test('converts from feet and inches and back', () {
      final height = HeightValue.fromFeetInches(5, 9);

      expect(height.centimetres, closeTo(175.26, 0.01));
      expect(height.feet, 5);
      expect(height.inches, 9);
    });

    test('a ft/in round trip does not drift', () {
      for (var feet = 4; feet <= 7; feet++) {
        for (var inches = 0; inches < 12; inches++) {
          final height = HeightValue.fromFeetInches(feet, inches);
          expect(height.feet, feet, reason: "$feet'$inches");
          expect(height.inches, inches, reason: "$feet'$inches");
        }
      }
    });

    test('flags implausible values without rejecting them', () {
      expect(const HeightValue(centimetres: 175).isPlausible, isTrue);
      expect(const HeightValue(centimetres: 35).isPlausible, isFalse);
    });
  });

  group('weight stores kilograms canonically', () {
    test('converts from pounds and back', () {
      final weight = WeightValue.fromPounds(154);

      expect(weight.kilograms, closeTo(69.85, 0.01));
      expect(weight.pounds, closeTo(154, 0.001));
    });
  });

  test('currency carries amount, code and period', () {
    const income = CurrencyValue(amount: 150000);

    expect(income.currencyCode, 'PKR');
    expect(income.period, IncomePeriod.perMonth);
    expect(CurrencyValue.fromJson(income.toJson()), income);
  });

  group('repeatable groups support both shapes families use (§6.2)', () {
    test('the "2 brothers, 1 married" shorthand needs no per-person entry', () {
      const brothers = RepeatableGroupValue(total: 2, marriedCount: 1);

      expect(brothers.effectiveTotal, 2);
      expect(brothers.hasDetail, isFalse);
      expect(brothers.isEmpty, isFalse);
    });

    test('per-person detail infers the total', () {
      const sisters = RepeatableGroupValue(
        entries: [
          {'name': 'Ayesha'},
          {'name': 'Fatima'},
        ],
      );

      expect(sisters.effectiveTotal, 2);
      expect(sisters.hasDetail, isTrue);
    });

    test('an explicit total wins over the entry count', () {
      const brothers = RepeatableGroupValue(
        total: 3,
        entries: [
          {'name': 'Ali'},
        ],
      );

      expect(brothers.effectiveTotal, 3);
    });
  });

  group('age derivation', () {
    test('counts a birthday that has already passed', () {
      expect(
        ageOn(DateTime(1995, 3, 15), DateTime(2026, 8, 4)),
        31,
      );
    });

    test('does not count a birthday still to come this year', () {
      expect(
        ageOn(DateTime(1995, 12, 15), DateTime(2026, 8, 4)),
        30,
      );
    });

    test('counts the birthday itself', () {
      expect(
        ageOn(DateTime(1995, 8, 4), DateTime(2026, 8, 4)),
        31,
      );
    });
  });

  group('validation', () {
    test('a required empty field fails, an optional one does not', () {
      expect(
        Validator.validate(value: '  ', isRequired: true),
        ValidationError.required,
      );
      expect(Validator.validate(value: '  ', isRequired: false), isNull);
    });

    test('accepts the phone shapes Pakistani families actually write', () {
      const rule = ValidationRule.phone;
      for (final number in [
        '+92 300 1234567',
        '03001234567',
        '+92-300-1234567',
        '(021) 35678900',
      ]) {
        expect(
          Validator.validate(value: number, isRequired: true, rule: rule),
          isNull,
          reason: number,
        );
      }
    });

    test('rejects text and implausible lengths in a phone field', () {
      const rule = ValidationRule.phone;
      for (final number in ['not a number', '12345', '1' * 16]) {
        expect(
          Validator.validate(value: number, isRequired: true, rule: rule),
          ValidationError.badPhoneNumber,
          reason: number,
        );
      }
    });

    test('measures length in code points, not UTF-16 units', () {
      // Six Urdu letters. String.length would report more.
      const urdu = 'محمدعلی';
      expect(
        Validator.validate(
          value: urdu,
          isRequired: true,
          rule: const ValidationRule(maxLength: 7),
        ),
        isNull,
      );
    });

    test('rejects a future date of birth and an implausible year', () {
      const rule = ValidationRule.pastDate;
      expect(
        Validator.validate(
          value: DateTime.now().add(const Duration(days: 1)),
          isRequired: true,
          rule: rule,
        ),
        ValidationError.dateInFuture,
      );
      expect(
        Validator.validate(
          value: DateTime(1850),
          isRequired: true,
          rule: rule,
        ),
        ValidationError.implausibleDate,
      );
    });
  });
}
