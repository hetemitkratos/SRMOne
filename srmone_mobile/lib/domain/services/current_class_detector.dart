// lib/domain/services/current_class_detector.dart
// Clock-based current/upcoming class detector — new mobile-only feature.
// Specification: plan.md §2.4
//
// Parses slot timings like "08:00 - 08:50" or "13:25 - 14:15".
// Handles 12-hour AM/PM rollover for afternoon hours 01:xx–05:xx.

enum ClassTimeState { ongoing, upcomingNext, completed, future }

class ClassTimeInfo {
  final ClassTimeState state;
  final int startMinutes;
  final int endMinutes;

  /// For ongoing: progress 0.0..1.0 of elapsed time within the class period.
  final double? progressFraction;

  /// For upcomingNext: minutes until class starts.
  final int? minutesUntilStart;

  const ClassTimeInfo({
    required this.state,
    required this.startMinutes,
    required this.endMinutes,
    this.progressFraction,
    this.minutesUntilStart,
  });
}

class TimetableSlotWithTiming {
  final String courseCode;
  final String courseTitle;
  final String timing; // e.g. "08:00 - 08:50"
  final int hourIndex;
  final String day;

  const TimetableSlotWithTiming({
    required this.courseCode,
    required this.courseTitle,
    required this.timing,
    required this.hourIndex,
    required this.day,
  });
}

class CurrentClassDetector {
  /// Parses a timing string like "08:00 - 08:50" or "13:25 - 14:15" into
  /// (startMinutes, endMinutes) since local midnight.
  ///
  /// Handles the 12-hour rollover heuristic for afternoon hours:
  /// Hours 01..05 (which appear as 1-digit in 12-hour format) → add 12 hours.
  static (int start, int end)? parseTiming(String timing) {
    final re = RegExp(r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$');
    final match = re.firstMatch(timing.trim());
    if (match == null) return null;

    int startH = int.parse(match.group(1)!);
    final int startM = int.parse(match.group(2)!);
    int endH = int.parse(match.group(3)!);
    final int endM = int.parse(match.group(4)!);

    // Afternoon heuristic: hour < 7 → add 12 (SRM timings run 8am-6pm)
    if (startH < 7) startH += 12;
    if (endH < 7) endH += 12;

    return (startH * 60 + startM, endH * 60 + endM);
  }

  /// Classifies each slot in [slots] relative to the current local time.
  ///
  /// Only processes slots for [dayLabel] (e.g. 'Day 3').
  /// Returns all slots annotated with their [ClassTimeInfo].
  static List<(TimetableSlotWithTiming, ClassTimeInfo)> classify(
    List<TimetableSlotWithTiming> slots,
    String dayLabel,
    DateTime now,
  ) {
    final nowMinutes = now.hour * 60 + now.minute;

    final todaySlots = slots.where((s) => s.day == dayLabel).toList()
      ..sort((a, b) => a.hourIndex.compareTo(b.hourIndex));

    bool upcomingAssigned = false;

    return todaySlots.map((slot) {
      final parsed = parseTiming(slot.timing);
      if (parsed == null) {
        return (
          slot,
          const ClassTimeInfo(
            state: ClassTimeState.future,
            startMinutes: 0,
            endMinutes: 0,
          )
        );
      }
      final (start, end) = parsed;

      ClassTimeInfo info;

      if (nowMinutes >= start && nowMinutes < end) {
        // ONGOING
        final elapsed = nowMinutes - start;
        final duration = end - start;
        final progress = duration > 0 ? elapsed / duration : 0.0;
        info = ClassTimeInfo(
          state: ClassTimeState.ongoing,
          startMinutes: start,
          endMinutes: end,
          progressFraction: progress.clamp(0.0, 1.0),
        );
      } else if (end <= nowMinutes) {
        // COMPLETED
        info = ClassTimeInfo(
          state: ClassTimeState.completed,
          startMinutes: start,
          endMinutes: end,
        );
      } else if (!upcomingAssigned && start > nowMinutes) {
        // UP NEXT — first future slot only
        upcomingAssigned = true;
        info = ClassTimeInfo(
          state: ClassTimeState.upcomingNext,
          startMinutes: start,
          endMinutes: end,
          minutesUntilStart: start - nowMinutes,
        );
      } else {
        info = ClassTimeInfo(
          state: ClassTimeState.future,
          startMinutes: start,
          endMinutes: end,
        );
      }

      return (slot, info);
    }).toList();
  }
}
