// lib/domain/services/calendar_day_resolver.dart
// Unified CalendarDayResolver — merges the conflicting holiday logic between:
//   - backend/utils/schedule_utils.js
//   - frontend/src/utils/calendarTimetableSync.js
//
// Bug Fix #4: Single authoritative day-order and holiday resolution source.
// All date keys use LOCAL time — never UTC.
//
// Specification: plan.md §2.3, architecture.md §5

/// Day status types matching the CalendarDayResolver spec.
enum DayStatusType { working, holiday, weekend, unknown }

class DayStatus {
  final DayStatusType type;
  final int? dayOrderNum; // 1..5 if working, null otherwise
  final String event;
  final bool isHoliday;
  final bool isWeekend;
  final bool isWorkingDay;
  final String dayLabel; // 'Day 1' .. 'Day 5' or ''

  const DayStatus({
    required this.type,
    this.dayOrderNum,
    required this.event,
    required this.isHoliday,
    required this.isWeekend,
    required this.isWorkingDay,
    required this.dayLabel,
  });
}

/// Raw entry from the parsed calendar JSON (one day row from the HTML table).
class CalendarEntry {
  final String date; // Local YYYY-MM-DD
  final String day; // 'Mon', 'Tue', ..., 'Sat', 'Sun'
  final String dayOrder; // '1'..'5', '-', '', or other
  final String event; // Holiday name or empty

  const CalendarEntry({
    required this.date,
    required this.day,
    required this.dayOrder,
    required this.event,
  });
}

class CalendarDayResolver {
  /// Formats a local [DateTime] to a YYYY-MM-DD string using LOCAL date parts.
  /// NEVER uses .toUtc() — this preserves IST (UTC+5:30) date identity.
  static String localDateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Resolves the status of [date] from [calendarMap].
  ///
  /// [calendarMap]: Map<YYYY-MM-DD, CalendarEntry> produced by AcaParser.
  ///
  /// Unified Holiday Detection (Bug Fix #4):
  ///   - isHoliday: event.toLowerCase().contains('holiday') OR
  ///     (!isWeekend && dayOrderNum == null && event.trim().isNotEmpty)
  ///   - isWorkingDay: dayOrderNum != null && !isHoliday
  static DayStatus getDayStatus(
    Map<String, CalendarEntry> calendarMap,
    DateTime date,
  ) {
    final key = localDateKey(date);
    final entry = calendarMap[key];

    // Weekend detection (also applies when entry is absent)
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    if (entry == null) {
      // No calendar data for this date — use weekday heuristic
      if (isWeekend) {
        return const DayStatus(
          type: DayStatusType.weekend,
          dayOrderNum: null,
          event: '',
          isHoliday: false,
          isWeekend: true,
          isWorkingDay: false,
          dayLabel: '',
        );
      }
      // Weekday with no calendar entry: treat as unknown (not counted)
      return const DayStatus(
        type: DayStatusType.unknown,
        dayOrderNum: null,
        event: '',
        isHoliday: false,
        isWeekend: false,
        isWorkingDay: false,
        dayLabel: '',
      );
    }

    // Parse dayOrderNum: '1'..'5' → 1..5; '-', '', non-numeric → null
    final int? dayOrderNum = _parseDayOrder(entry.dayOrder);

    // Unified holiday rule (Bug Fix #4)
    final isHoliday = entry.event.toLowerCase().contains('holiday') ||
        (!isWeekend && dayOrderNum == null && entry.event.trim().isNotEmpty);

    final isWorkingDay = dayOrderNum != null && !isHoliday;

    final dayLabel = isWorkingDay ? 'Day $dayOrderNum' : '';

    DayStatusType type;
    if (isWeekend) {
      type = DayStatusType.weekend;
    } else if (isHoliday) {
      type = DayStatusType.holiday;
    } else if (isWorkingDay) {
      type = DayStatusType.working;
    } else {
      type = DayStatusType.unknown;
    }

    return DayStatus(
      type: type,
      dayOrderNum: dayOrderNum,
      event: entry.event,
      isHoliday: isHoliday,
      isWeekend: isWeekend,
      isWorkingDay: isWorkingDay,
      dayLabel: dayLabel,
    );
  }

  /// Parses the dayOrder string from the calendar HTML table.
  /// Returns null for '-', empty string, or any non-numeric value.
  static int? _parseDayOrder(String raw) {
    final trimmed = raw.trim();
    if (trimmed == '-' || trimmed.isEmpty) return null;
    final n = int.tryParse(trimmed);
    if (n == null || n < 1 || n > 5) return null;
    return n;
  }

  /// Parses month name strings from both formats found in the academia calendar:
  ///   "Aug '26"  (short month + 2-digit year)
  ///   "August 2026" (full month + 4-digit year)
  ///
  /// Returns a [DateTime] at day 1 of that month, or null on parse failure.
  static DateTime? parseMonthName(String raw) {
    final trimmed = raw.trim();

    // Try "Aug '26" format
    final shortRe = RegExp(r"^([A-Za-z]{3})\s+'(\d{2})$");
    final shortMatch = shortRe.firstMatch(trimmed);
    if (shortMatch != null) {
      final monthStr = shortMatch.group(1)!;
      final yearShort = int.parse(shortMatch.group(2)!);
      final year = 2000 + yearShort;
      final month = _monthAbbrevToInt(monthStr);
      if (month != null) return DateTime(year, month, 1);
    }

    // Try "August 2026" format
    final longRe = RegExp(r'^([A-Za-z]+)\s+(\d{4})$');
    final longMatch = longRe.firstMatch(trimmed);
    if (longMatch != null) {
      final monthStr = longMatch.group(1)!;
      final year = int.parse(longMatch.group(2)!);
      final month = _monthFullToInt(monthStr);
      if (month != null) return DateTime(year, month, 1);
    }

    return null;
  }

  static const _abbrevMonths = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };

  static const _fullMonths = {
    'January': 1,
    'February': 2,
    'March': 3,
    'April': 4,
    'May': 5,
    'June': 6,
    'July': 7,
    'August': 8,
    'September': 9,
    'October': 10,
    'November': 11,
    'December': 12,
  };

  static int? _monthAbbrevToInt(String abbrev) => _abbrevMonths[
      abbrev.substring(0, 1).toUpperCase() + abbrev.substring(1).toLowerCase()];

  static int? _monthFullToInt(String full) => _fullMonths[
      full.substring(0, 1).toUpperCase() + full.substring(1).toLowerCase()];
}
