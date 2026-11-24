import 'package:flutter_test/flutter_test.dart';
import 'package:social_sport_ladder/Utilities/misc.dart';
import 'package:social_sport_ladder/constants/constants.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  setUp(() {
    enableImages = false;
  });

  group('Edmonton timezone data', () {
    tz.Location edmonton() => tz.getLocation('America/Edmonton');

    test('uses daylight time after the 2026 clock change date', () {
      final result = tz.TZDateTime.from(
        DateTime.utc(2026, 11, 24, 19, 37),
        edmonton(),
      );

      expect(result.hour, 13);
      expect(result.minute, 37);
      expect(result.timeZoneOffset, const Duration(hours: -6));
    });

    test('uses daylight time immediately before the 2026 transition boundary',
        () {
      final result = tz.TZDateTime.from(
        DateTime.utc(2026, 11, 1, 7, 59),
        edmonton(),
      );

      expect(result.hour, 1);
      expect(result.minute, 59);
      expect(result.timeZoneOffset, const Duration(hours: -6));
    });

    test('does not fall back at the 2026 transition boundary', () {
      final result = tz.TZDateTime.from(
        DateTime.utc(2026, 11, 1, 8),
        edmonton(),
      );

      expect(result.hour, 2);
      expect(result.minute, 0);
      expect(result.timeZoneOffset, const Duration(hours: -6));
    });
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
