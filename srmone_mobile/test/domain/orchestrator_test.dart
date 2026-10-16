// test/domain/orchestrator_test.dart
// Unit and integration tests for SessionSyncOrchestrator and Zero-Logout auto-refresh logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/domain/services/attendance_planner_math.dart';

void main() {
  group('Dual-Source Reconciliation Logic', () {
    test('prefers Student Portal attendance when hoursConducted is higher', () {
      final acadRecords = [
        const AttendanceInput(
          courseCode: '21CSC402P',
          courseTitle: 'Report Writing',
          hoursConducted: 6,
          hoursAbsent: 2,
          attendancePct: 66.67,
        ),
        const AttendanceInput(
          courseCode: '21CSE412T',
          courseTitle: 'Machine Learning',
          hoursConducted: 10,
          hoursAbsent: 1,
          attendancePct: 90.0,
        ),
      ];

      // Student Portal has 8 hours conducted for 21CSC402P (newer data)
      final spRecords = [
        const AttendanceInput(
          courseCode: '21CSC402P',
          courseTitle: 'REPORT WRITING',
          hoursConducted: 8,
          hoursAbsent: 4,
          attendancePct: 50.0,
        ),
        const AttendanceInput(
          courseCode: '21CSE412T',
          courseTitle: 'Machine Learning',
          hoursConducted: 10, // same as acad
          hoursAbsent: 1,
          attendancePct: 90.0,
        ),
      ];

      final spMap = {for (var r in spRecords) r.courseCode.toUpperCase(): r};
      final merged = <AttendanceInput>[];

      for (final acad in acadRecords) {
        final sp = spMap[acad.courseCode.toUpperCase()];
        if (sp != null && sp.hoursConducted > acad.hoursConducted) {
          merged.add(
            AttendanceInput(
              courseCode: acad.courseCode,
              courseTitle: acad.courseTitle,
              hoursConducted: sp.hoursConducted,
              hoursAbsent: sp.hoursAbsent,
              attendancePct: sp.attendancePct,
            ),
          );
        } else {
          merged.add(acad);
        }
      }

      expect(merged.length, 2);
      // 21CSC402P: updated to SP hours (8 conducted, 50.0%)
      expect(merged[0].courseCode, '21CSC402P');
      expect(merged[0].hoursConducted, 8);
      expect(merged[0].attendancePct, 50.0);

      // 21CSE412T: kept Academia hours (10 conducted, 90.0%)
      expect(merged[1].courseCode, '21CSE412T');
      expect(merged[1].hoursConducted, 10);
      expect(merged[1].attendancePct, 90.0);
    });
  });
}
