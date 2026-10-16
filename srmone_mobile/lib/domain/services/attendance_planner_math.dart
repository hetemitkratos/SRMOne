// lib/domain/services/attendance_planner_math.dart
// Exact port of AttendancePlanner.jsx calculation logic with 6 verified bug fixes:
//   Bug Fix #2: T=100 division-by-zero guard (web version divided by (100-T) unchecked)
//   Bug Fix #3: Both unweighted and weighted overall % exposed clearly
//
// ALL formulas are grounded in plan.md §2.1, §2.2 and architecture.md §5.

import 'dart:math';

/// A single attendance record from the database.
class AttendanceInput {
  final String courseCode;
  final String courseTitle;
  final int hoursConducted;
  final int hoursAbsent;
  final double attendancePct;
  final String category;
  final String facultyName;
  final String slot;
  final String roomNo;

  const AttendanceInput({
    required this.courseCode,
    required this.courseTitle,
    required this.hoursConducted,
    required this.hoursAbsent,
    required this.attendancePct,
    this.category = '',
    this.facultyName = '',
    this.slot = '',
    this.roomNo = '',
  });

  int get hoursPresent => hoursConducted - hoursAbsent;
}

// ─── Reach Target Mode ────────────────────────────────────────────────────────

class ReachTargetResult {
  final String courseCode;
  final String courseTitle;
  final int conducted;
  final int present;
  final int absent;
  final double pct;

  /// Classes needed to reach target. 0 = already at/above target.
  /// -1 = unreachable (only when T=100 and absent > 0).
  final int needed;
  final int bunkable;
  final double newPct;
  final bool alreadyAbove;

  /// Only true when target == 100 and hoursAbsent > 0.
  final bool isUnreachable100;

  const ReachTargetResult({
    required this.courseCode,
    required this.courseTitle,
    required this.conducted,
    required this.present,
    required this.absent,
    required this.pct,
    required this.needed,
    required this.bunkable,
    required this.newPct,
    required this.alreadyAbove,
    required this.isUnreachable100,
  });
}

/// Computes "Reach Target" mode results for a list of attendance records.
///
/// [target]: Desired attendance % from 50 to 100 (inclusive).
///
/// Sorting: unreachable subjects first (needed == -1), then descending needed,
/// then descending pct.
List<ReachTargetResult> computeReachTarget(
  List<AttendanceInput> records,
  int target, // 50..100
) {
  final results = records.map((rec) {
    final c = rec.hoursConducted; // conducted
    final a = rec.hoursAbsent; // absent
    final p = c - a; // present
    final pct = c > 0 ? (p / c) * 100 : 0.0;
    final t = target.toDouble();

    int needed = 0;
    int bunkable = 0;
    double newPct = pct;
    bool isUnreachable100 = false;

    // ── BUG FIX #2: T=100 division-by-zero guard ─────────────────────────────
    if (target == 100) {
      if (a > 0) {
        // Cannot reach 100% if any class was missed
        needed = -1;
        bunkable = 0;
        newPct = pct;
        isUnreachable100 = true;
      } else {
        // Already at 100%
        needed = 0;
        bunkable = 0;
        newPct = c > 0 ? 100.0 : 0.0;
      }
    } else {
      // Standard case: 50 <= T < 100
      if (c > 0 && pct < t) {
        // ceil((T * C - 100 * P) / (100 - T))
        final raw = (t * c - 100 * p) / (100 - t);
        needed = max(0, raw.ceil());
        newPct = needed > 0 ? (100 * (p + needed)) / (c + needed) : pct;
      } else if (c > 0 && pct >= t) {
        // floor((100 * P / T) - C)
        final raw = (100 * p) / t - c;
        bunkable = max(0, raw.floor());
        needed = 0;
        newPct = pct;
      }
    }

    return ReachTargetResult(
      courseCode: rec.courseCode,
      courseTitle: rec.courseTitle,
      conducted: c,
      present: p,
      absent: a,
      pct: pct,
      needed: needed,
      bunkable: bunkable,
      newPct: newPct,
      alreadyAbove: needed == 0 && !isUnreachable100,
      isUnreachable100: isUnreachable100,
    );
  }).toList();

  // Sort: unreachable (needed=-1) first, then by descending needed, then pct
  results.sort((a, b) {
    if (a.isUnreachable100 && !b.isUnreachable100) return -1;
    if (!a.isUnreachable100 && b.isUnreachable100) return 1;
    final cmp = b.needed.compareTo(a.needed);
    if (cmp != 0) return cmp;
    return b.pct.compareTo(a.pct);
  });

  return results;
}

// ─── Plan Holiday Mode ────────────────────────────────────────────────────────

/// A resolved timetable slot for plan holiday calculations.
class TimetableSlot {
  final String courseCode;
  final String day; // 'Day 1' .. 'Day 5'
  final int hourIndex;

  const TimetableSlot({
    required this.courseCode,
    required this.day,
    required this.hourIndex,
  });
}

/// Result of planning a holiday range for one subject.
class PlanHolidayResult {
  final String courseCode;
  final String courseTitle;
  final int conducted;
  final int present;
  final double currentPct;
  final int missed; // classes to be missed in the selected range
  final int newConducted;
  final double newPct;
  final double drop; // percentage points dropped
  final bool willDropBelow75;
  final int recoveryNeeded; // classes to attend to recover to 75% after holiday

  const PlanHolidayResult({
    required this.courseCode,
    required this.courseTitle,
    required this.conducted,
    required this.present,
    required this.currentPct,
    required this.missed,
    required this.newConducted,
    required this.newPct,
    required this.drop,
    required this.willDropBelow75,
    required this.recoveryNeeded,
  });
}

/// Day status resolved from CalendarCache.
class ResolvedDayStatus {
  final bool isWorking;
  final String? dayLabel; // 'Day 1' .. 'Day 5' or null

  const ResolvedDayStatus({required this.isWorking, this.dayLabel});
}

/// Computes the impact of a holiday date range on attendance.
///
/// [fromDate] and [toDate]: inclusive local date range.
/// [records]: current attendance records.
/// [timetableSlots]: all timetable slots from cached timetable.
/// [calendarResolver]: function mapping a local date to its day status.
///   If null, falls back to weekday mapping (Mon=Day1 .. Fri=Day5).
List<PlanHolidayResult> computePlanHoliday({
  required DateTime fromDate,
  required DateTime toDate,
  required List<AttendanceInput> records,
  required List<TimetableSlot> timetableSlots,
  ResolvedDayStatus Function(DateTime date)? calendarResolver,
}) {
  // Index timetable by day label → list of course codes
  final dayToSlots = <String, List<String>>{};
  for (final slot in timetableSlots) {
    dayToSlots.putIfAbsent(slot.day, () => []).add(slot.courseCode);
  }

  // Count missed classes per course code over the date range
  final missed = <String, int>{};
  var cur = DateTime(fromDate.year, fromDate.month, fromDate.day);
  final end = DateTime(toDate.year, toDate.month, toDate.day);

  while (!cur.isAfter(end)) {
    ResolvedDayStatus status;

    if (calendarResolver != null) {
      status = calendarResolver(cur);
    } else {
      // Fallback: Mon=Day1 .. Fri=Day5, Sat/Sun = not working
      final wd = cur.weekday; // 1=Mon .. 7=Sun
      if (wd >= DateTime.monday && wd <= DateTime.friday) {
        status = ResolvedDayStatus(
          isWorking: true,
          dayLabel: 'Day $wd',
        );
      } else {
        status = const ResolvedDayStatus(isWorking: false);
      }
    }

    if (status.isWorking && status.dayLabel != null) {
      final slotsForDay = dayToSlots[status.dayLabel] ?? [];
      for (final code in slotsForDay) {
        missed[code] = (missed[code] ?? 0) + 1;
      }
    }

    cur = cur.add(const Duration(days: 1));
  }

  // Compute impact per record
  return records.map((rec) {
    final c = rec.hoursConducted;
    final p = rec.hoursPresent;
    final m = missed[rec.courseCode] ?? 0;
    final currentPct = c > 0 ? (p / c) * 100.0 : 0.0;
    final newConducted = c + m;
    final newPct = newConducted > 0 ? (p / newConducted) * 100.0 : 0.0;
    final drop = currentPct - newPct;
    final willDropBelow75 = (currentPct >= 75.0) && (newPct < 75.0);

    // Recovery: how many classes to attend after the holiday to get back to 75%
    // ceil((75 * newConducted - 100 * P) / 25)
    int recoveryNeeded = 0;
    if (newPct < 75.0) {
      final raw = (75.0 * newConducted - 100.0 * p) / 25.0;
      recoveryNeeded = max(0, raw.ceil());
    }

    return PlanHolidayResult(
      courseCode: rec.courseCode,
      courseTitle: rec.courseTitle,
      conducted: c,
      present: p,
      currentPct: currentPct,
      missed: m,
      newConducted: newConducted,
      newPct: newPct,
      drop: drop,
      willDropBelow75: willDropBelow75,
      recoveryNeeded: recoveryNeeded,
    );
  }).toList();
}

// ─── Attendance Screen Summary Math (§2.1) ────────────────────────────────────

class AttendanceSummary {
  /// Arithmetic mean of each subject's attendancePct.
  /// Matches legacy Attendance.jsx header display.
  final double unweightedMeanPct;

  /// (totalPresent / totalConducted) * 100.
  /// Used for holiday projection comparisons.
  final double weightedOverallPct;

  final int above75;
  final int below75;
  final int total;

  const AttendanceSummary({
    required this.unweightedMeanPct,
    required this.weightedOverallPct,
    required this.above75,
    required this.below75,
    required this.total,
  });
}

/// ── BUG FIX #3: Both unweighted and weighted metrics exposed clearly ──────────
AttendanceSummary computeAttendanceSummary(List<AttendanceInput> records) {
  if (records.isEmpty) {
    return const AttendanceSummary(
      unweightedMeanPct: 0,
      weightedOverallPct: 0,
      above75: 0,
      below75: 0,
      total: 0,
    );
  }

  double sumPct = 0.0;
  int totalPresent = 0;
  int totalConducted = 0;
  int above75 = 0;

  for (final r in records) {
    sumPct += r.attendancePct;
    totalPresent += r.hoursPresent;
    totalConducted += r.hoursConducted;
    if (r.attendancePct >= 75.0) above75++;
  }

  final unweighted = sumPct / records.length;
  final weighted =
      totalConducted > 0 ? (totalPresent / totalConducted) * 100 : 0.0;

  return AttendanceSummary(
    unweightedMeanPct: unweighted,
    weightedOverallPct: weighted,
    above75: above75,
    below75: records.length - above75,
    total: records.length,
  );
}

/// Per-subject card bunkable/needed at the fixed 75% threshold (§2.1).
class SubjectCardMetrics {
  final int present;
  final int conducted;
  final int absent;
  final double pct;
  final bool isGood;
  final bool isWarning;
  final bool isDanger;
  final int bunkable75; // classes can be skipped while staying ≥75%
  final int needed75; // classes to attend to reach 75%

  const SubjectCardMetrics({
    required this.present,
    required this.conducted,
    required this.absent,
    required this.pct,
    required this.isGood,
    required this.isWarning,
    required this.isDanger,
    required this.bunkable75,
    required this.needed75,
  });
}

SubjectCardMetrics computeSubjectCardMetrics(AttendanceInput rec) {
  final c = rec.hoursConducted;
  final a = rec.hoursAbsent;
  final p = c - a;
  final pct = c > 0 ? (p / c) * 100 : 0.0;

  final isGood = pct >= 75.0;
  final isWarning = pct >= 50.0 && pct < 75.0;
  final isDanger = pct < 50.0;

  int bunkable75 = 0;
  int needed75 = 0;

  if (isGood) {
    bunkable75 = max(0, ((p - 0.75 * c) / 0.75).floor().clamp(0, 9999));
  } else {
    needed75 = max(0, ((0.75 * c - p) / 0.25).ceil().clamp(0, 9999));
  }

  return SubjectCardMetrics(
    present: p,
    conducted: c,
    absent: a,
    pct: pct,
    isGood: isGood,
    isWarning: isWarning,
    isDanger: isDanger,
    bunkable75: bunkable75,
    needed75: needed75,
  );
}
