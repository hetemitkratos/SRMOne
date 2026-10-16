// test/scrapers/academia_parsers_test.dart
// Parsers for the Academia pages that feed profile, marks, timetable and
// calendar. HTML below is synthetic (no real student data).

import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/domain/services/session_sync_orchestrator.dart';
import 'package:srmone_mobile/scrapers/academia/academia_client.dart';
import 'package:srmone_mobile/scrapers/academia/academia_parsers.dart';

const _timetablePage = '''
<html><body>
<table>
  <tr><td>Registration Number:</td><td>RA0000000000001</td><td>Name:</td><td>Test Student</td></tr>
  <tr><td>Batch:</td><td>2</td><td>Program:</td><td>B.Tech</td></tr>
  <tr><td>Semester:</td><td>:</td><td>7</td></tr>
</table>
<table>
  <tr><td>Counselor</td><td></td>
      <td>Dr. Jane Doe<br>Faculty Advisor<br>jane@example.com<br>9000000000</td></tr>
</table>
<table>
  <tr><th>S.No</th><th>Course Code</th><th>Course Title</th><th>Credit</th>
      <th>Category</th><th>Course Type</th><th>Faculty Name</th><th>Slot</th><th>Room No.</th></tr>
  <tr><td>1</td><td>21CSC101T</td><td>Algorithms</td><td>3</td><td>Professional Core</td>
      <td>Theory</td><td>Dr. A B (100001)</td><td>A-</td><td>LH101</td></tr>
  <tr><td>2</td><td>21CSC101P</td><td>Algorithms Lab</td><td>1</td><td>Professional Core</td>
      <td>Practical</td><td>Dr. A B (100001)</td><td>P1-P2-</td><td>LAB1</td></tr>
</table>
<table>
  <tr><th>Course Code</th><th>Course Title</th><th>Category</th><th>Faculty Name</th>
      <th>Slot</th><th>Room No</th><th>Hours Conducted</th><th>Hours Absent</th><th>Attn %</th></tr>
  <tr><td>21CSC101T<br>Regular</td><td>Algorithms</td><td>Professional Core</td>
      <td>Dr. A B (100001)</td><td>A</td><td>LH101</td><td>20</td><td>2</td><td>90.00</td></tr>
</table>
<table>
  <tr><th>Course Code</th><th>Course Type</th><th>Test Performance</th></tr>
  <tr><td>21CSC101T</td><td>Theory</td>
      <td><table><tr><td>FT-I/5.00<br>4.50</td><td>FT-II/10.00<br>Abs</td></tr></table></td></tr>
  <tr><td>21CSC101P</td><td>Practical</td><td></td></tr>
</table>
</body></html>
''';

const _unifiedPage = '''
<table>
  <tr><td>FROM</td><td>08:00 - 08:50</td><td>08:50 - 09:40</td></tr>
  <tr><td>TO</td><td></td><td></td></tr>
  <tr><td>Day 2</td><td>A</td><td>P2</td></tr>
  <tr><td>Day 1</td><td>P1 / X</td><td>A</td></tr>
</table>
''';

const _calendarPage = '''
<table>
  <tr><th>Dt</th><th>Day</th><th>Jul '26</th><th>DO</th>
      <th>Dt</th><th>Day</th><th>Aug '26</th><th>DO</th></tr>
  <tr><td>1</td><td>Wed</td><td></td><td>1</td><td>1</td><td>Sat</td><td></td><td>-</td></tr>
  <tr><td>2</td><td>Thu</td><td>Holiday - Test</td><td>-</td><td>3</td><td>Mon</td><td></td><td>2</td></tr>
  <tr><td>31</td><td>Fri</td><td></td><td>2</td><td></td><td></td><td></td><td></td></tr>
</table>
''';

void main() {
  group('AcademiaParsers on the My_Time_Table page', () {
    test('parseAttendancePage reads every section from one parse', () {
      final page = AcademiaParsers.parseAttendancePage(_timetablePage);
      expect(
          page.attendance.map((a) => a.courseCode),
          AcademiaParsers.parseAttendance(_timetablePage)
              .map((a) => a.courseCode));
      expect(page.profile, AcademiaParsers.parseStudentProfile(_timetablePage));
      expect(page.marks.map((m) => m.courseCode),
          AcademiaParsers.parseMarks(_timetablePage).map((m) => m.courseCode));
      expect(
          page.courses, AcademiaParsers.parseTimetableCourses(_timetablePage));
      expect(page.advisors, AcademiaParsers.parseAdvisors(_timetablePage));
    });

    test('parseAttendance picks the Attn % table, not the course list', () {
      final records = AcademiaParsers.parseAttendance(_timetablePage);
      expect(records, hasLength(1));
      expect(records.first.courseCode, '21CSC101T');
      expect(records.first.hoursConducted, 20);
      expect(records.first.category, 'Professional Core');
      expect(records.first.facultyName, 'Dr. A B (100001)');
    });

    test('parseStudentProfile pairs labels with values and skips colons', () {
      final info = AcademiaParsers.parseStudentProfile(_timetablePage);
      expect(info['Registration Number'], 'RA0000000000001');
      expect(info['Name'], 'Test Student');
      expect(info['Batch'], '2');
      expect(info['Semester'], '7');
    });

    test('parseMarks reads nested test cells without inventing totals', () {
      final marks = AcademiaParsers.parseMarks(_timetablePage);
      expect(marks.map((m) => m.courseCode), ['21CSC101T', '21CSC101P']);
      final tests = marks.first.tests;
      expect(tests.map((t) => t.toJson()).toList(), [
        {'testName': 'FT-I', 'scored': '4.50', 'maxMarks': '5.00'},
        {'testName': 'FT-II', 'scored': 'Abs', 'maxMarks': '10.00'},
      ]);
      expect(marks.last.tests, isEmpty);
    });

    test('parseAdvisors splits the counselor cell by line', () {
      final advisors = AcademiaParsers.parseAdvisors(_timetablePage);
      expect(advisors.single['name'], 'Dr. Jane Doe');
      expect(advisors.single['email'], 'jane@example.com');
    });
  });

  group('Timetable merge', () {
    test('joins course slots with the unified grid, sorted by day and hour',
        () {
      final slotMap = AcademiaParsers.parseUnifiedSlotMap(_unifiedPage);
      expect(slotMap.keys, containsAll(['A', 'P1', 'P2', 'X']));

      final courses = AcademiaParsers.mergeTimetable(
        AcademiaParsers.parseTimetableCourses(_timetablePage),
        slotMap,
      );
      expect(courses, hasLength(2));

      final theory = courses.first;
      expect(theory['roomNo'], 'LH101');
      final schedule =
          (theory['schedule'] as List).cast<Map<String, dynamic>>();
      expect(schedule.map((e) => '${e['day']}#${e['hourIndex']}'),
          ['Day 1#2', 'Day 2#1']);
      expect(schedule.first['timing'], '08:50 - 09:40');

      final lab = (courses.last['schedule'] as List).cast<Map>();
      expect(lab.map((e) => e['slotToken']), ['P1', 'P2']);
    });
  });

  group('Calendar', () {
    test('parseCalendar groups day rows under each month header', () {
      final months = AcademiaParsers.parseCalendar(_calendarPage);
      expect(months.map((m) => m['month']), ["Jul '26", "Aug '26"]);
      final july = (months.first['days'] as List).cast<Map>();
      expect(july, hasLength(3));
      expect(july[1]['event'], 'Holiday - Test');
      // Empty date cells in the August column are skipped.
      expect((months.last['days'] as List), hasLength(2));
    });

    test('normalizeCalendarMonths converts day numbers to YYYY-MM-DD', () {
      final months =
          normalizeCalendarMonths(AcademiaParsers.parseCalendar(_calendarPage));
      final july = (months.first['days'] as List).cast<Map>();
      expect(july.map((d) => d['date']),
          ['2026-07-01', '2026-07-02', '2026-07-31']);
      expect(july.first['dayOrder'], '1');
    });

    test('semesterFor maps July to December to odd', () {
      expect(semesterFor(DateTime(2026, 10, 16)), 'odd');
      expect(semesterFor(DateTime(2026, 7, 1)), 'odd');
      expect(semesterFor(DateTime(2027, 2, 1)), 'even');
    });
  });

  group('Session expiry detection', () {
    test('a logged-in page that merely links to sign-in is not expired', () {
      expect(
        AcademiaClient.looksLikeSigninPage(
          'https://academia.srmist.edu.in/srm_university/academia-academic-services/page/My_Time_Table_2023_24',
          '<a href="/accounts/p/1/signin?logout=true">Sign out</a><table></table>',
        ),
        isFalse,
      );
    });

    test('a redirect to the accounts sign-in page is expired', () {
      expect(
        AcademiaClient.looksLikeSigninPage(
            'https://academia.srmist.edu.in/accounts/p/1/signin', ''),
        isTrue,
      );
      expect(
        AcademiaClient.looksLikeSigninPage(
            'https://academia.srmist.edu.in/', 'Please sign in to continue'),
        isTrue,
      );
    });
  });
}
