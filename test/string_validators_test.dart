import 'package:flutter_test/flutter_test.dart';
import 'package:social_sport_ladder/Utilities/string_validators.dart';

void main() {
  group('Email Validation', () {
    test('Valid email returns true', () {
      expect('test@example.com'.isValidEmail(), isTrue);
    });

    test('Invalid email returns false', () {
      expect('invalid-email'.isValidEmail(), isFalse);
    });

    test('no .com returns false', () {
      expect('test@example'.isValidEmail(), isFalse);
    });
    test('no @ returns false', () {
      expect('test_example.com'.isValidEmail(), isFalse);
    });
    test('Empty email returns false', () {
      expect(''.isValidEmail(), isFalse);
    });
  });
}