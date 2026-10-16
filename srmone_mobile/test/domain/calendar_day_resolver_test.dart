// test/domain/calendar_day_resolver_test.dart
// Unit tests for CalendarDayResolver — unified holiday detection, date keys, month parsing.

import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/domain/services/calendar_day_resolver.dart';

void main() {
  group('localDateKey', () {
    test('uses local date, not UTC', () {
      // IST = UTC+5:30, so 2026-10-16 00:00 IST = 2026-10-15 18:30 UTC
      // localDateKey must return 2026-10-16, not 2026-10-15
      final d = DateTime(2026, 10, 16, 0, 0, 0);
      expect(CalendarDayResolver.localDateKey(d), '2026-10-16');
    });

    test('zero-pads month and day', () {
      expect(
          CalendarDayResolver.localDateKey(DateTime(2026, 1, 5)), '2026-01-05');
    });
  });

  group('getDayStatus', () {
    CalendarEntry entry({
      required String date,
      required String day,
      required String dayOrder,
      String event = '',
    }) =>
        CalendarEntry(date: date, day: day, dayOrder: dayOrder, event: event);

    test(
        'working day with dayOrder "3" → DayStatusType.working, dayLabel "Day 3"',
        () {
      final map = {
        '2026-10-19': entry(date: '2026-10-19', day: 'Mon', dayOrder: '3')
      };
      final status =
          CalendarDayResolver.getDayStatus(map, DateTime(2026, 10, 19));
      expect(status.type, DayStatusType.working);
      expect(status.dayOrderNum, 3);
      expect(status.dayLabel, 'Day 3');
      expect(status.isWorkingDay, true);
      expect(status.isHoliday, false);
    });

    test('holiday via event text → isHoliday = true', () {
      final map = {
        '2026-10-20': entry(
            date: '2026-10-20',
            day: 'Tue',
            dayOrder: '-',
            event: 'Diwali Holiday')
      };
      final status =
          CalendarDayResolver.getDayStatus(map, DateTime(2026, 10, 20));
      expect(status.isHoliday, true);
      expect(status.type, DayStatusType.holiday);
      expect(status.isWorkingDay, false);
    });

    test('weekday with non-null event but no dayOrder → holiday (Bug Fix #4)',
        () {
      // Non-weekend, dayOrder = "-", event = "Faculty Development Programme"
      // → isHoliday should be true (working day off, not a numeric day order)
      final map = {
        '2026-10-21': entry(
            date: '2026-10-21',
            day: 'Wed',
            dayOrder: '-',
            event: 'Faculty Development Programme')
      };
      final status =
          CalendarDayResolver.getDayStatus(map, DateTime(2026, 10, 21));
      expect(status.isHoliday, true);
      expect(status.isWorkingDay, false);
    });

    test('Saturday → weekend, not a working day', () {
      final map = <String, CalendarEntry>{};
      final status =
          CalendarDayResolver.getDayStatus(map, DateTime(2026, 10, 17));
      expect(status.isWeekend, true);
      expect(status.isWorkingDay, false);
    });

    test('dayOrder "-" → dayOrderNum = null', () {
      final map = {
        '2026-10-22': entry(date: '2026-10-22', day: 'Thu', dayOrder: '-')
      };
      final status =
          CalendarDayResolver.getDayStatus(map, DateTime(2026, 10, 22));
      expect(status.dayOrderNum, isNull);
    });
  });

  group('parseMonthName', () {
    test('parses "Aug \'26" format', () {
      final result = CalendarDayResolver.parseMonthName("Aug '26");
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 8);
      expect(result.day, 1);
    });

    test('parses "August 2026" format', () {
      final result = CalendarDayResolver.parseMonthName('August 2026');
      expect(result, isNotNull);
      expect(result!.year, 2026);
      expect(result.month, 8);
    });

    test('returns null for garbage input', () {
      expect(CalendarDayResolver.parseMonthName('not-a-month'), isNull);
    });

    test('parses January edge case', () {
      final result = CalendarDayResolver.parseMonthName("Jan '26");
      expect(result!.month, 1);
      expect(result.year, 2026);
    });
  });
}
