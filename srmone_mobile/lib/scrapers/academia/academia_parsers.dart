// lib/scrapers/academia/academia_parsers.dart
// Parsers for SRM Academia portal HTML responses (attendance, profile, marks, timetable, calendar).
// Ported from academia-backend/academia-scraper/cmd/loginprobe/parsers.go

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/constants/portal_endpoints.dart';
import '../../domain/services/attendance_planner_math.dart';

class AcademiaParsers {
  AcademiaParsers._();

  // ─── 1. Attendance Parser ───────────────────────────────────────────────────

  /// Parses attendance records from the decoded HTML table of My_Time_Table_2023_24.
  /// Looks for the table whose headers contain 'Attn %' or 'Course Code'.
  static List<AttendanceInput> parseAttendance(String decodedHtml) {
    final doc = html_parser.parse(decodedHtml);
    final tables = doc.querySelectorAll('table');

    Element? targetTable;
    List<String> headers = [];

    for (final table in tables) {
      final thList = table.querySelectorAll('th');
      final firstRowCells = table.querySelectorAll('tr').isNotEmpty
          ? table.querySelectorAll('tr').first.querySelectorAll('td, th')
          : <Element>[];

      final candidateCells = thList.isNotEmpty ? thList : firstRowCells;
      final rowHeaders = candidateCells
          .map((c) => _cleanCellText(c.text))
          .where((h) => h.isNotEmpty)
          .toList();

      if (rowHeaders.any((h) => h.contains('Attn %') || h == 'Attn %') ||
          (rowHeaders.contains('Course Code') &&
              rowHeaders.contains('Course Title'))) {
        targetTable = table;
        headers = rowHeaders;
        break;
      }
    }

    if (targetTable == null) {
      throw const FormatException('Attendance table not found in HTML');
    }

    final rows = targetTable.querySelectorAll('tr');
    if (rows.length <= 1) {
      return [];
    }

    final List<AttendanceInput> records = [];

    for (int i = 1; i < rows.length; i++) {
      final cells = rows[i]
          .querySelectorAll('td')
          .map((c) => _cleanCellText(c.text))
          .toList();
      if (cells.isEmpty || cells[0].isEmpty) continue;

      final map = <String, String>{};
      for (int h = 0; h < headers.length; h++) {
        map[headers[h]] = h < cells.length ? cells[h] : '';
      }

      String courseCode = map['Course Code'] ??
          map['Course\nCode'] ??
          (cells.isNotEmpty ? cells[0] : '');
      if (courseCode.contains('\n')) {
        courseCode = courseCode.split('\n').first.trim();
      }

      final courseTitle =
          map['Course Title'] ?? (cells.length > 1 ? cells[1] : '');
      final conductedStr = map['Hours Conducted'] ?? '';
      final absentStr = map['Hours Absent'] ?? '';
      final pctStr = map['Attn %'] ?? map['Attendance %'] ?? '';

      final conducted =
          int.tryParse(conductedStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      final absent =
          int.tryParse(absentStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
      final pct = double.tryParse(pctStr.replaceAll(RegExp(r'[^\d.]'), '')) ??
          (conducted > 0 ? ((conducted - absent) / conducted) * 100 : 0.0);

      records.add(
        AttendanceInput(
          courseCode: courseCode,
          courseTitle: courseTitle,
          hoursConducted: conducted,
          hoursAbsent: absent,
          attendancePct: pct,
        ),
      );
    }

    return records;
  }

  // ─── 2. Student Profile Parser ──────────────────────────────────────────────

  /// Parses student details from Student Info or Academic Reports HTML.
  static Map<String, dynamic> parseStudentProfile(String decodedHtml) {
    final doc = html_parser.parse(decodedHtml);
    final profile = <String, dynamic>{};

    // Table key-value pairs (TD label : TD value)
    final rows = doc.querySelectorAll('tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length >= 2) {
        for (int i = 0; i < cells.length - 1; i += 2) {
          final label = _cleanCellText(cells[i].text).replaceAll(':', '');
          final val = _cleanCellText(cells[i + 1].text);
          if (label.isNotEmpty && val.isNotEmpty) {
            profile[label] = val;
          }
        }
      }
    }

    return profile;
  }

  // ─── 3. Student Photo Download URL ──────────────────────────────────────────

  /// Derives the photo download URL from student profile report HTML.
  static String? extractStudentPhotoDownloadURL(String decodedHtml) {
    final doc = html_parser.parse(decodedHtml);
    final img = doc.querySelector(
        'img[src*="Photo_Upload_Student_Report"], img[src*="Your_Photo/image/"]');

    if (img != null) {
      for (final attr in ['src', 'downqual', 'medqual', 'lowqual']) {
        final val = img.attributes[attr]?.trim();
        if (val != null && val.contains('/image/')) {
          final idx = val.lastIndexOf('/image/');
          final filepath = val.substring(idx + '/image/'.length).trim();
          if (filepath.isNotEmpty) {
            return '${PortalEndpoints.academiaBaseUrl}'
                '/srm_university/academia-academic-services/report/Student_Profile_Report/'
                '${PortalEndpoints.defaultStudentPhotoReportId}'
                '/Your_Photo/download-file?filepath=/${Uri.encodeComponent(filepath)}'
                '&digestValue=e30=';
          }
        }
      }
    }

    return null;
  }

  // ─── 4. Marks Parser (Academic Reports) ─────────────────────────────────────

  /// Parses test marks from Academic Reports HTML.
  /// Bug Fix #6: Parses test-level rows strictly without inventing letter grades.
  static List<Map<String, dynamic>> parseMarks(String decodedHtml) {
    final doc = html_parser.parse(decodedHtml);
    final tables = doc.querySelectorAll('table');
    final List<Map<String, dynamic>> courses = [];

    for (final table in tables) {
      final ths = table
          .querySelectorAll('th')
          .map((e) => _cleanCellText(e.text))
          .toList();
      if (ths.any((h) => h.contains('Course Code')) &&
          ths.any((h) => h.contains('Test') || h.contains('Mark'))) {
        final rows = table.querySelectorAll('tr');
        for (int i = 1; i < rows.length; i++) {
          final tds = rows[i]
              .querySelectorAll('td')
              .map((e) => _cleanCellText(e.text))
              .toList();
          if (tds.length >= 4) {
            courses.add({
              'courseCode': tds[0],
              'courseTitle': tds.length > 1 ? tds[1] : '',
              'testName': tds.length > 2 ? tds[2] : '',
              'obtained': tds.length > 3 ? tds[3] : '',
              'maxMark': tds.length > 4 ? tds[4] : '',
              'source': 'academia',
            });
          }
        }
      }
    }

    return courses;
  }

  // ─── 5. Timetable Parser ────────────────────────────────────────────────────

  /// Parses course details and slot schedules from My_Time_Table_2023_24.
  static List<Map<String, dynamic>> parseTimetableCourses(String decodedHtml) {
    final doc = html_parser.parse(decodedHtml);
    final tables = doc.querySelectorAll('table');
    final List<Map<String, dynamic>> courses = [];

    for (final table in tables) {
      final ths = table
          .querySelectorAll('th')
          .map((e) => _cleanCellText(e.text))
          .toList();
      if (ths.contains('Course Code') && ths.contains('Slot')) {
        final rows = table.querySelectorAll('tr');
        for (int i = 1; i < rows.length; i++) {
          final tds = rows[i]
              .querySelectorAll('td')
              .map((e) => _cleanCellText(e.text))
              .toList();
          if (tds.length >= 6) {
            final map = <String, String>{};
            for (int h = 0; h < ths.length && h < tds.length; h++) {
              map[ths[h]] = tds[h];
            }
            courses.add({
              'courseCode': map['Course Code'] ?? tds[0],
              'courseTitle': map['Course Title'] ?? tds[1],
              'category': map['Category'] ?? (tds.length > 2 ? tds[2] : ''),
              'facultyName':
                  map['Faculty Name'] ?? (tds.length > 3 ? tds[3] : ''),
              'slot': map['Slot'] ?? (tds.length > 4 ? tds[4] : ''),
              'roomNo': map['Room No'] ?? (tds.length > 5 ? tds[5] : ''),
            });
          }
        }
        break;
      }
    }

    return courses;
  }

  static String _cleanCellText(String text) {
    return text.replaceAll('\u00A0', ' ').trim();
  }
}
