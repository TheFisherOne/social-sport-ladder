import 'package:flutter_test/flutter_test.dart';
import 'package:social_sport_ladder/screens/calendar_page.dart';

void main() {
  group('shouldAutoCreatePlayDate', () {
    final DateTime ladderToday = DateTime(2030, 1, 15);
    final DateTime selectedDay = DateTime(2030, 1, 16);

    test('returns false when the selected date has history files', () {
      final result = shouldAutoCreatePlayDate(
        selectedDay: selectedDay,
        ladderToday: ladderToday,
        selectedDayEvents: [Event('FILE: history_2030.01.16.csv')],
        playOnCalendarEvents: {},
      );

      expect(result, isFalse);
    });

    test('returns false when the selected date is before today', () {
      final result = shouldAutoCreatePlayDate(
        selectedDay: DateTime(2030, 1, 14),
        ladderToday: ladderToday,
        selectedDayEvents: const [],
        playOnCalendarEvents: {},
      );

      expect(result, isFalse);
    });

    test('returns false when a play date already exists', () {
      final result = shouldAutoCreatePlayDate(
        selectedDay: selectedDay,
        ladderToday: ladderToday,
        selectedDayEvents: [Event('play:18:00')],
        playOnCalendarEvents: {
          selectedDay: [Event('play:18:00')],
        },
      );

      expect(result, isFalse);
    });

    test('returns true for a future date without files or an existing play date', () {
      final result = shouldAutoCreatePlayDate(
        selectedDay: selectedDay,
        ladderToday: ladderToday,
        selectedDayEvents: const [],
        playOnCalendarEvents: {},
      );

      expect(result, isTrue);
    });
  });
}

