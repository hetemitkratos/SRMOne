// lib/domain/services/timetable_schedule.dart
// Reads the cached timetable and calendar JSON written by
// SessionSyncOrchestrator, shared by the Overview and Timetable screens.

import 'dart:convert';

import 'calendar_day_resolver.dart';
import 'current_class_detector.dart';

class TimetableSchedule {
  TimetableSchedule._();

  /// Decodes `TimetableCache.coursesJson`; returns [] on null or bad JSON.
  static List<Map<String, dynamic>> parseCourses(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      return (jsonDecode(jsonStr) as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Builds the class slots for [dayLabel] ('Day 1'..'Day 5') from each
  /// course's `schedule` entries, sorted by hour.
  static List<TimetableSlotWithTiming> slotsForDay(
    List<Map<String, dynamic>> courses,
    String dayLabel,
  ) {
    final slots = <TimetableSlotWithTiming>[];
    for (final c in courses) {
      final schedule = c['schedule'];
      if (schedule is! List) continue;
      for (final entry in schedule.whereType<Map<String, dynamic>>()) {
        if (entry['day']?.toString().trim() != dayLabel) continue;
        slots.add(TimetableSlotWithTiming(
          courseCode: c['courseCode']?.toString() ?? '',
          courseTitle: c['courseTitle']?.toString() ?? '',
          timing: entry['timing']?.toString() ?? '',
          hourIndex: (entry['hourIndex'] as num?)?.toInt() ?? 0,
          day: dayLabel,
        ));
      }
    }
    slots.sort((a, b) => a.hourIndex.compareTo(b.hourIndex));
    return slots;
  }

  /// Day label → list of `{code, title, room, timing}` for the poster export.
  static Map<String, List<Map<String, String>>> daySchedule(
      List<Map<String, dynamic>> courses) {
    final rooms = {
      for (final c in courses)
        c['courseCode']?.toString() ?? '': c['roomNo']?.toString() ?? '-',
    };
    return {
      for (final day in ['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5'])
        day: [
          for (final s in slotsForDay(courses, day))
            {
              'code': s.courseCode,
              'title': s.courseTitle,
              'room': rooms[s.courseCode] ?? '-',
              'timing': s.timing,
            }
        ],
    };
  }

  /// Decodes `CalendarCache.monthsJson` into a `YYYY-MM-DD` → entry map.
  static Map<String, CalendarEntry> parseCalendar(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final map = <String, CalendarEntry>{};
      for (final month in jsonDecode(jsonStr) as List<dynamic>) {
        if (month is! Map<String, dynamic> || month['days'] is! List) continue;
        for (final day in (month['days'] as List).whereType<Map>()) {
          final date = day['date']?.toString() ?? '';
          if (date.isEmpty) continue;
          map[date] = CalendarEntry(
            date: date,
            day: day['day']?.toString() ?? '',
            dayOrder: day['dayOrder']?.toString() ?? '',
            event: day['event']?.toString() ?? '',
          );
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }
}
