import 'package:flutter_test/flutter_test.dart';
import 'package:social_sport_ladder/Utilities/misc.dart';
import 'package:social_sport_ladder/constants/constants.dart';

void main() {
  setUp(() {
    enableImages = false;
  });

  group('daysBetween', () {
    test('should return 0 when the dates are the same', () {
      final from = DateTime(2025, 4, 18);
      final to = DateTime(2025, 4, 18);

      final result = daysBetween(from, to);

      expect(result, 0);
    });

    test('should return 1 when the dates are one day apart', () {
      final from = DateTime(2025, 4, 18);
      final to = DateTime(2025, 4, 19);

      final result = daysBetween(from, to);

      expect(result, 1);
    });

    test('should return the correct number of days when dates are multiple days apart', () {
      final from = DateTime(2025, 4, 18);
      final to = DateTime(2025, 4, 25);

      final result = daysBetween(from, to);

      expect(result, 7);
    });

    test('should handle leap years correctly', () {
      final from = DateTime(2024, 2, 28);
      final to = DateTime(2024, 3, 1);

      final result = daysBetween(from, to);

      expect(result, 2);
    });

    test('should return a negative value when the "from" date is after the "to" date', () {
      final from = DateTime(2025, 4, 25);
      final to = DateTime(2025, 4, 18);

      final result = daysBetween(from, to);

      expect(result, -7);
    });
  });
}