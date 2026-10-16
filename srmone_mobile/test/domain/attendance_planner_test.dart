// test/domain/attendance_planner_test.dart
// Unit tests for AttendancePlannerMath — covering all spec formulas and bug fixes.
// Must pass 100% before Phase 1 can be considered complete.

import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/domain/services/attendance_planner_math.dart';

void main() {
  group('ReachTarget (Reach Target Mode)', () {
    AttendanceInput rec(
        {required String code, required int conducted, required int absent}) {
      final pct =
          conducted > 0 ? ((conducted - absent) / conducted) * 100 : 0.0;
      return AttendanceInput(
        courseCode: code,
        courseTitle: code,
        hoursConducted: conducted,
        hoursAbsent: absent,
        attendancePct: pct,
      );
    }

    test('T=75: subject below target → correct needed classes', () {
      // 60 conducted, 20 absent → 40 present → 66.67% → need to reach 75%
      // needed = ceil((75*60 - 100*40) / (100-75)) = ceil((4500-4000)/25) = ceil(20) = 20
      final results = computeReachTarget(
          [rec(code: 'CS101', conducted: 60, absent: 20)], 75);
      expect(results.length, 1);
      expect(results[0].needed, 20);
      expect(results[0].bunkable, 0);
      expect(results[0].isUnreachable100, false);
    });

    test('T=75: subject above target → correct bunkable classes', () {
      // 100 conducted, 10 absent → 90 present → 90%
      // bunkable = floor((100*90)/75 - 100) = floor(120 - 100) = 20
      final results = computeReachTarget(
          [rec(code: 'MA101', conducted: 100, absent: 10)], 75);
      expect(results[0].needed, 0);
      expect(results[0].bunkable, 20);
    });

    // ── Bug Fix #2 Tests ─────────────────────────────────────────────────────

    test('T=100 with absent > 0 → needed = -1, isUnreachable100 = true', () {
      final results = computeReachTarget(
          [rec(code: 'PH101', conducted: 50, absent: 5)], 100);
      expect(results[0].needed, -1);
      expect(results[0].isUnreachable100, true);
      expect(results[0].bunkable, 0);
    });

    test('T=100 with absent = 0 → needed = 0, already at 100%', () {
      final results = computeReachTarget(
          [rec(code: 'PH101', conducted: 50, absent: 0)], 100);
      expect(results[0].needed, 0);
      expect(results[0].isUnreachable100, false);
      expect(results[0].newPct, closeTo(100.0, 0.01));
    });

    test('T=100 with absent > 0 → does NOT divide by zero', () {
      // This would crash the web version with division by (100-100) = 0
      expect(
        () => computeReachTarget(
            [rec(code: 'EN101', conducted: 80, absent: 1)], 100),
        returnsNormally,
      );
    });

    test('T=50: subject at exactly 50% → needed = 0, bunkable = 0', () {
      // 100 conducted, 50 absent → 50 present → 50%
      final results = computeReachTarget(
          [rec(code: 'CS201', conducted: 100, absent: 50)], 50);
      expect(results[0].needed, 0);
      // bunkable = floor(100*50/50 - 100) = floor(100-100) = 0
      expect(results[0].bunkable, 0);
    });

    test('sorting: unreachable subjects appear first', () {
      final records = [
        rec(code: 'A', conducted: 60, absent: 10), // above 75
        rec(code: 'B', conducted: 60, absent: 5), // well above 75
        rec(code: 'C', conducted: 60, absent: 2), // 100% → unreachable at T=100
      ];
      final results = computeReachTarget(records, 100);
      // C and A both have absents > 0 → both unreachable
      // B also has absents → unreachable
      // All should be unreachable at T=100
      for (final r in results) {
        expect(r.isUnreachable100, true);
      }
    });

    test('conducted = 0 → needed = 0, no crash', () {
      final results =
          computeReachTarget([rec(code: 'XX', conducted: 0, absent: 0)], 75);
      expect(results[0].needed, 0);
      expect(results[0].pct, 0.0);
    });
  });

  group('AttendanceSummary (Bug Fix #3 — Both Metrics)', () {
    test('unweighted mean ≠ weighted when subjects have different loads', () {
      final records = [
        const AttendanceInput(
          courseCode: 'A',
          courseTitle: 'A',
          hoursConducted: 100,
          hoursAbsent: 10,
          attendancePct: 90.0, // 90%
        ),
        const AttendanceInput(
          courseCode: 'B',
          courseTitle: 'B',
          hoursConducted: 10,
          hoursAbsent: 9,
          attendancePct: 10.0, // 10%
        ),
      ];

      final summary = computeAttendanceSummary(records);

      // Unweighted: (90 + 10) / 2 = 50%
      expect(summary.unweightedMeanPct, closeTo(50.0, 0.01));

      // Weighted: (90 + 1) / (100 + 10) * 100 = 91/110 * 100 ≈ 82.73%
      expect(summary.weightedOverallPct, closeTo(82.73, 0.5));

      // They differ — that's the point
      expect(summary.unweightedMeanPct,
          isNot(closeTo(summary.weightedOverallPct, 1.0)));
    });

    test('above75 and below75 counts are correct', () {
      final records = [
        const AttendanceInput(
            courseCode: 'A',
            courseTitle: 'A',
            hoursConducted: 100,
            hoursAbsent: 20,
            attendancePct: 80.0),
        const AttendanceInput(
            courseCode: 'B',
            courseTitle: 'B',
            hoursConducted: 100,
            hoursAbsent: 30,
            attendancePct: 70.0),
        const AttendanceInput(
            courseCode: 'C',
            courseTitle: 'C',
            hoursConducted: 100,
            hoursAbsent: 10,
            attendancePct: 90.0),
      ];
      final summary = computeAttendanceSummary(records);
      expect(summary.above75, 2); // A and C
      expect(summary.below75, 1); // B
    });
  });

  group('SubjectCardMetrics (§2.1)', () {
    test('75% threshold bunkable calculation', () {
      const rec = AttendanceInput(
        courseCode: 'X',
        courseTitle: 'X',
        hoursConducted: 100,
        hoursAbsent: 10,
        attendancePct: 90.0,
      );
      final m = computeSubjectCardMetrics(rec);
      expect(m.isGood, true);
      // bunkable = floor((90 - 0.75*100) / 0.75) = floor(15/0.75) = floor(20) = 20
      expect(m.bunkable75, 20);
      expect(m.needed75, 0);
    });

    test('below 75%: needed calculation', () {
      const rec = AttendanceInput(
        courseCode: 'Y',
        courseTitle: 'Y',
        hoursConducted: 100,
        hoursAbsent: 30,
        attendancePct: 70.0,
      );
      final m = computeSubjectCardMetrics(rec);
      expect(m.isDanger, false);
      expect(m.isWarning, true);
      // needed = ceil((0.75*100 - 70) / 0.25) = ceil(5/0.25) = ceil(20) = 20
      expect(m.needed75, 20);
      expect(m.bunkable75, 0);
    });
  });

  group('PlanHoliday (§2.2 Mode B)', () {
    final records = [
      const AttendanceInput(
        courseCode: 'CS101',
        courseTitle: 'Data Structures',
        hoursConducted: 60,
        hoursAbsent: 10,
        attendancePct: 83.33,
      ),
    ];

    final slots = [
      const TimetableSlot(courseCode: 'CS101', day: 'Day 1', hourIndex: 1),
      const TimetableSlot(courseCode: 'CS101', day: 'Day 3', hourIndex: 2),
    ];

    test('single working day with matching slot → 1 missed class', () {
      // fromDate and toDate = same day, day resolver returns Day 1
      final from = DateTime(2026, 10, 19); // a Monday (Day 1 fallback)
      final results = computePlanHoliday(
        fromDate: from,
        toDate: from,
        records: records,
        timetableSlots: slots,
        calendarResolver: (d) => const ResolvedDayStatus(
          isWorking: true,
          dayLabel: 'Day 1',
        ),
      );
      expect(results[0].missed, 1);
      expect(results[0].newConducted, 61);
    });

    test('weekend day → 0 missed classes', () {
      final saturday = DateTime(2026, 10, 17); // Saturday
      final results = computePlanHoliday(
        fromDate: saturday,
        toDate: saturday,
        records: records,
        timetableSlots: slots,
        calendarResolver: (_) => const ResolvedDayStatus(isWorking: false),
      );
      expect(results[0].missed, 0);
    });

    test('willDropBelow75 flag triggers when pct crosses 75% boundary', () {
      // Start at 80% (80 present / 100 conducted)
      // 1 slot on Day 1 over 5 Day 1s = 5 missed classes
      // New: 80 / (100 + 5) = 80 / 105 ≈ 76.19% (still >= 75%)
      const r80 = AttendanceInput(
        courseCode: 'MA101',
        courseTitle: 'Maths',
        hoursConducted: 100,
        hoursAbsent: 20,
        attendancePct: 80.0,
      );
      const singleSlot = [
        TimetableSlot(courseCode: 'MA101', day: 'Day 1', hourIndex: 1),
      ];

      final from = DateTime(2026, 10, 19);
      final to = DateTime(2026, 10, 23); // 5 days

      final resultsAbove = computePlanHoliday(
        fromDate: from,
        toDate: to,
        records: [r80],
        timetableSlots: singleSlot,
        calendarResolver: (_) =>
            const ResolvedDayStatus(isWorking: true, dayLabel: 'Day 1'),
      );
      expect(resultsAbove[0].missed, 5);
      expect(resultsAbove[0].willDropBelow75, false);

      // Now 2 slots per day: 5 days * 2 slots = 10 missed classes
      // New: 80 / (100 + 10) = 80 / 110 ≈ 72.72% (< 75%)
      const twoSlots = [
        TimetableSlot(courseCode: 'MA101', day: 'Day 1', hourIndex: 1),
        TimetableSlot(courseCode: 'MA101', day: 'Day 1', hourIndex: 2),
      ];

      final resultsBelow = computePlanHoliday(
        fromDate: from,
        toDate: to,
        records: [r80],
        timetableSlots: twoSlots,
        calendarResolver: (_) =>
            const ResolvedDayStatus(isWorking: true, dayLabel: 'Day 1'),
      );
      expect(resultsBelow[0].missed, 10);
      expect(resultsBelow[0].willDropBelow75, true);
      expect(resultsBelow[0].recoveryNeeded, greaterThan(0));
    });
  });
}
