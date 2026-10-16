// lib/scrapers/academia/academia_parsers.dart
// Parsers for SRM Academia portal HTML responses (attendance, profile, marks, timetable, calendar).
// Ported from academia-backend/academia-scraper/cmd/loginprobe/parsers.go

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../core/constants/portal_endpoints.dart';
import '../../domain/services/attendance_planner_math.dart';

/// Everything the app reads from the My_Time_Table page.
class AcademiaPageData {
  final List<AttendanceInput> attendance;
  final Map<String, String> profile;
  final List<AcademiaMarkRecord> marks;
  final List<Map<String, String>> courses;
  final List<Map<String, String>> advisors;

  const AcademiaPageData({
    required this.attendance,
    required this.profile,
    required this.marks,
    required this.courses,
    required this.advisors,
  });
}

class AcademiaParsers {
  AcademiaParsers._();

  // ─── 1. Attendance Parser ───────────────────────────────────────────────────

  /// Parses attendance records from the decoded HTML table of My_Time_Table_2023_24.
  /// Looks for the table whose headers contain 'Attn %' or 'Course Code'.
  static List<AttendanceInput> parseAttendance(String decodedHtml) =>
      parseAttendanceDoc(html_parser.parse(decodedHtml));

  static List<AttendanceInput> parseAttendanceDoc(Document doc) {
    final tables = doc.querySelectorAll('table');

    Element? targetTable;
    List<String> headers = [];

    // Prefer the table with an `Attn %` header (the personal timetable on the
    // same page also has Course Code/Course Title headers).
    for (final pass in [true, false]) {
      if (targetTable != null) break;
      for (final table in tables) {
        final thList = table.querySelectorAll('th');
        final firstRowCells = table.querySelectorAll('tr').isNotEmpty
            ? table.querySelectorAll('tr').first.querySelectorAll('td, th')
            : <Element>[];

        final candidateCells = thList.isNotEmpty ? thList : firstRowCells;
        // Kept index-aligned with the data cells (an empty header must not
        // shift later columns), with whitespace collapsed so a header
        // broken by <br> ("Hours<br>Conducted") still matches.
        final rowHeaders = candidateCells
            .map((c) => cellText(c).replaceAll(RegExp(r'\s+'), ' ').trim())
            .toList();

        final matches = pass
            ? rowHeaders.any((h) => h.contains('Attn %'))
            : rowHeaders.contains('Course Code') &&
                rowHeaders.contains('Course Title');
        if (matches) {
          targetTable = table;
          headers = rowHeaders;
          break;
        }
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
      final cells =
          rows[i].querySelectorAll('td').map((c) => cellText(c)).toList();
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
          category: map['Category'] ?? '',
          facultyName: map['Faculty Name'] ?? '',
          slot: map['Slot'] ?? '',
          roomNo: map['Room No'] ?? map['Room No.'] ?? '',
        ),
      );
    }

    return records;
  }

  /// Parses every section of the decoded My_Time_Table page from a single
  /// HTML parse. Attendance errors propagate; the other sections are
  /// best-effort and come back empty when their table can't be read.
  static AcademiaPageData parseAttendancePage(String decodedHtml) {
    final doc = html_parser.parse(decodedHtml);
    T orEmpty<T>(T Function() parse, T empty) {
      try {
        return parse();
      } catch (_) {
        return empty;
      }
    }

    return AcademiaPageData(
      attendance: parseAttendanceDoc(doc),
      profile: orEmpty(() => parseStudentProfileDoc(doc), const {}),
      marks: orEmpty(() => parseMarksDoc(doc), const []),
      courses: orEmpty(() => parseTimetableCoursesDoc(doc), const []),
      advisors: orEmpty(() => parseAdvisorsDoc(doc), const []),
    );
  }

  // ─── 2. Student Profile Parser ──────────────────────────────────────────────

  /// Parses the student info table (the one containing `Registration Number:`)
  /// from My_Time_Table_2023_24 into a label → value map.
  /// Labels have their trailing `:` stripped; `:` separator cells are skipped.
  static Map<String, String> parseStudentProfile(String decodedHtml) =>
      parseStudentProfileDoc(html_parser.parse(decodedHtml));

  static Map<String, String> parseStudentProfileDoc(Document doc) {
    Element? table;
    for (final t in doc.querySelectorAll('table')) {
      if (_headerTexts(t).contains('Registration Number:')) {
        table = t;
        break;
      }
    }
    if (table == null) return {};

    final info = <String, String>{};
    for (final row in table.querySelectorAll('tr')) {
      final cells =
          row.querySelectorAll('th, td').map((c) => cellText(c)).toList();
      for (int i = 0; i < cells.length; i++) {
        var key = cells[i].trim();
        if (key.isEmpty || key == ':') continue;
        if (key.endsWith(':')) key = key.substring(0, key.length - 1).trim();
        if (key.isEmpty) continue;

        int v = i + 1;
        while (v < cells.length && cells[v].trim().isEmpty) {
          v++;
        }
        if (v < cells.length && cells[v].trim() == ':') v++;
        while (v < cells.length && cells[v].trim().isEmpty) {
          v++;
        }
        if (v >= cells.length) continue;

        final value = cells[v].trim();
        if (value.isNotEmpty && value != ':') info[key] = value;
      }
    }
    return info;
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

  // ─── 4. Marks Parser (My_Time_Table_2023_24) ────────────────────────────────

  /// Parses the `Test Performance` table into one entry per course.
  /// Bug Fix #6: keeps test-level rows only; never invents grades or totals.
  ///
  /// Each test cell reads like `FT-I/5.00` on its first line and the score on
  /// the following line(s).
  static List<AcademiaMarkRecord> parseMarks(String decodedHtml) =>
      parseMarksDoc(html_parser.parse(decodedHtml));

  static List<AcademiaMarkRecord> parseMarksDoc(Document doc) {
    Element? table;
    for (final t in doc.querySelectorAll('table')) {
      if (_headerTexts(t).contains('Test Performance')) {
        table = t;
        break;
      }
    }
    if (table == null) return [];

    final records = <AcademiaMarkRecord>[];
    final rows = _directRows(table);
    for (int i = 1; i < rows.length; i++) {
      final cells = rows[i]
          .children
          .where((e) => e.localName == 'td' || e.localName == 'th')
          .toList();
      if (cells.length < 2) continue;
      final code = cellText(cells[0]).trim();
      if (code.isEmpty) continue;

      final tests = <AcademiaMarkTest>[];
      if (cells.length >= 3) {
        for (final inner in cells[2].querySelectorAll('td')) {
          final test = _parseMarkTestCell(inner);
          if (test != null) tests.add(test);
        }
      }
      records.add(AcademiaMarkRecord(
        courseCode: code,
        courseType: cellText(cells[1]).trim(),
        tests: tests,
      ));
    }
    return records;
  }

  static AcademiaMarkTest? _parseMarkTestCell(Element cell) {
    final lines = cellText(cell)
        .split(RegExp(r'[\n\t]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    var name = lines.first;
    var max = '';
    final score = lines.length > 1 ? lines.sublist(1).join(' ') : '';
    final slash = name.lastIndexOf('/');
    if (slash >= 0) {
      max = name.substring(slash + 1).trim();
      name = name.substring(0, slash).trim();
    }
    if (name.isEmpty && score.isEmpty && max.isEmpty) return null;
    return AcademiaMarkTest(testName: name, scored: score, maxMarks: max);
  }

  // ─── 5. Personal Timetable Parser ───────────────────────────────────────────

  /// Parses the course table (headers include `Course Code` and `Slot`) from
  /// My_Time_Table_2023_24. Each row becomes a header → value map.
  static List<Map<String, String>> parseTimetableCourses(String decodedHtml) =>
      parseTimetableCoursesDoc(html_parser.parse(decodedHtml));

  static List<Map<String, String>> parseTimetableCoursesDoc(Document doc) {
    for (final table in doc.querySelectorAll('table')) {
      final headers = _headerTexts(table);
      if (!headers.contains('Course Code') || !headers.contains('Slot')) {
        continue;
      }
      final courses = <Map<String, String>>[];
      final rows = table.querySelectorAll('tr');
      for (int i = 1; i < rows.length; i++) {
        final cells =
            rows[i].querySelectorAll('th, td').map((c) => cellText(c)).toList();
        if (cells.length < 2 || cells[1].trim().isEmpty) continue;
        final record = <String, String>{};
        for (int h = 0; h < headers.length; h++) {
          record[headers[h]] = h < cells.length ? cells[h].trim() : '';
        }
        courses.add(record);
      }
      return courses;
    }
    return [];
  }

  /// Parses faculty advisors from the table whose headers contain `Counselor`.
  static List<Map<String, String>> parseAdvisors(String decodedHtml) =>
      parseAdvisorsDoc(html_parser.parse(decodedHtml));

  static List<Map<String, String>> parseAdvisorsDoc(Document doc) {
    for (final table in doc.querySelectorAll('table')) {
      if (!_headerTexts(table).contains('Counselor')) continue;
      final firstRow = table.querySelector('tr');
      if (firstRow == null) return [];
      final cells =
          firstRow.querySelectorAll('th, td').map((c) => cellText(c)).toList();
      final advisors = <Map<String, String>>[];
      for (int i = 2; i < cells.length; i++) {
        final lines = cells[i]
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        if (lines.isEmpty) continue;
        String at(int n) => n < lines.length ? lines[n] : '';
        advisors.add({
          'name': at(0),
          'role': at(1),
          'email': at(2),
          'phone': at(3),
        });
      }
      return advisors;
    }
    return [];
  }

  // ─── 6. Unified Timetable (Batch Slot Map) ──────────────────────────────────

  /// Parses the Unified_Time_Table grid (first cell `FROM`) into a map of
  /// slot token → schedule entries `{day, hourIndex, timing, slotToken}`.
  static Map<String, List<Map<String, dynamic>>> parseUnifiedSlotMap(
      String decodedHtml) {
    final doc = html_parser.parse(decodedHtml);
    List<List<String>>? grid;
    for (final table in doc.querySelectorAll('table')) {
      final rows = _tableMatrix(table);
      if (rows.isNotEmpty &&
          rows.first.isNotEmpty &&
          rows.first.first.trim() == 'FROM') {
        grid = rows;
        break;
      }
    }
    if (grid == null || grid.first.length < 2) return {};

    final timings = grid.first.sublist(1);
    final slotMap = <String, List<Map<String, dynamic>>>{};
    for (final row in grid.skip(1)) {
      if (row.isEmpty) continue;
      final day = row.first.trim();
      if (!day.startsWith('Day')) continue;
      for (int col = 1; col < row.length && col - 1 < timings.length; col++) {
        final text = row[col].trim();
        if (text.isEmpty) continue;
        final timing = timings[col - 1].trim();
        for (final token in text.split(RegExp(r'\s*/\s*|\n+'))) {
          final t = token.trim();
          if (t.isEmpty) continue;
          slotMap.putIfAbsent(t, () => []).add({
            'day': day,
            'hourIndex': col,
            'timing': timing,
            'slotToken': t,
          });
        }
      }
    }
    return slotMap;
  }

  /// Joins personal courses with the unified slot map. Each returned course has
  /// a `schedule` list sorted by day number then hour index.
  static List<Map<String, dynamic>> mergeTimetable(
    List<Map<String, String>> rawCourses,
    Map<String, List<Map<String, dynamic>>> slotMap,
  ) {
    int dayNum(String d) =>
        int.tryParse(RegExp(r'(\d+)').firstMatch(d)?.group(1) ?? '') ?? 999;

    return rawCourses.map((c) {
      final rawSlot = (c['Slot'] ?? '').trim();
      final schedule = <Map<String, dynamic>>[];
      for (final token in rawSlot.split('-')) {
        final t = token.trim();
        if (t.isEmpty) continue;
        for (final entry in slotMap[t] ?? const <Map<String, dynamic>>[]) {
          schedule.add({...entry, 'slotToken': t});
        }
      }
      schedule.sort((a, b) {
        final byDay =
            dayNum(a['day'] as String).compareTo(dayNum(b['day'] as String));
        if (byDay != 0) return byDay;
        return (a['hourIndex'] as int).compareTo(b['hourIndex'] as int);
      });
      return <String, dynamic>{
        'courseCode': (c['Course Code'] ?? '').trim(),
        'courseTitle': (c['Course Title'] ?? '').trim(),
        'credit': (c['Credit'] ?? '').trim(),
        'category': (c['Category'] ?? '').trim(),
        'courseType': (c['Course Type'] ?? '').trim(),
        'facultyName': (c['Faculty Name'] ?? '').trim(),
        'slot': rawSlot,
        'roomNo': (c['Room No.'] ?? c['Room No'] ?? '').trim(),
        'schedule': schedule,
      };
    }).toList();
  }

  // ─── 7. Academic Calendar Parser ────────────────────────────────────────────

  static final RegExp _monthRe = RegExp(
    r'^(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|Jul(y)?|'
    r'Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)\b',
    caseSensitive: false,
  );

  /// Heuristic calendar parser (Academic_Reports / Academic_Planner pages).
  /// Returns months as `{month, days: [{date, day, event, dayOrder}]}` where
  /// `date` is the raw day-of-month cell; callers convert it to YYYY-MM-DD.
  static List<Map<String, dynamic>> parseCalendar(String decodedHtml) {
    final doc = html_parser.parse(decodedHtml);
    int bestScore = 0;
    int bestHeaderRow = 0;
    List<List<String>> bestTable = [];

    for (final table in doc.querySelectorAll('table')) {
      final rows = _tableMatrix(table);
      for (int r = 0; r < rows.length && r < 5; r++) {
        final hits = rows[r].where((c) => _monthRe.hasMatch(c.trim())).length;
        if (hits > bestScore) {
          bestScore = hits;
          bestHeaderRow = r;
          bestTable = rows;
        }
      }
    }
    if (bestScore == 0 || bestTable.isEmpty) return [];

    final header = bestTable[bestHeaderRow];
    final groups = <({String name, int dt, int day, int ev, int dO})>[];
    for (int i = 0; i < header.length; i++) {
      if (i >= 2 && _monthRe.hasMatch(header[i].trim())) {
        groups.add(
            (name: header[i].trim(), dt: i - 2, day: i - 1, ev: i, dO: i + 1));
      }
    }
    if (groups.isEmpty && header.length >= 4) {
      for (int i = 0; i + 3 < header.length; i += 5) {
        var name = 'Month${groups.length + 1}';
        for (final c in header.sublist(i, (i + 5).clamp(0, header.length))) {
          if (_monthRe.hasMatch(c.trim())) {
            name = c.trim();
            break;
          }
        }
        groups.add((name: name, dt: i, day: i + 1, ev: i + 2, dO: i + 3));
      }
    }

    String at(List<String> row, int i) =>
        i >= 0 && i < row.length ? row[i].trim() : '';

    final months = <Map<String, dynamic>>[];
    for (final g in groups) {
      final days = <Map<String, String>>[];
      for (int r = bestHeaderRow + 1; r < bestTable.length; r++) {
        final row = bestTable[r];
        final date = at(row, g.dt);
        if (date.isEmpty) continue;
        days.add({
          'date': date,
          'day': at(row, g.day),
          'event': at(row, g.ev),
          'dayOrder': at(row, g.dO),
        });
      }
      months.add({'month': g.name, 'days': days});
    }
    return months;
  }

  // ─── Shared HTML helpers ────────────────────────────────────────────────────

  /// Extracts cell text the way the Go scraper does: `<br>`/`<hr>` and block
  /// elements become line breaks, runs of whitespace collapse per line.
  static String cellText(Element cell) {
    final b = StringBuffer();
    void walk(Node node) {
      if (node is Text) {
        b.write(node.data);
        return;
      }
      if (node is Element) {
        final tag = node.localName ?? '';
        if ((tag == 'br' || tag == 'hr') && !b.toString().endsWith('\n')) {
          b.write('\n');
        }
        for (final child in node.nodes) {
          walk(child);
        }
        if (_blockTags.contains(tag) && !b.toString().endsWith('\n')) {
          b.write('\n');
        }
      }
    }

    for (final child in cell.nodes) {
      walk(child);
    }
    return b
        .toString()
        .replaceAll('\u00A0', ' ')
        .split('\n')
        .map((l) => l.trim().split(RegExp(r'\s+')).join(' '))
        .where((l) => l.isNotEmpty)
        .join('\n')
        .trim();
  }

  static const _blockTags = {
    'div',
    'p',
    'section',
    'article',
    'header',
    'footer',
    'li',
    'tr',
    'table'
  };

  static List<String> _headerTexts(Element table) {
    final first = table.querySelector('tr');
    if (first == null) return [];
    return first.querySelectorAll('th, td').map((c) => cellText(c)).toList();
  }

  static List<List<String>> _tableMatrix(Element table) => table
      .querySelectorAll('tr')
      .map((r) => r.querySelectorAll('th, td').map((c) => cellText(c)).toList())
      .toList();

  static List<Element> _directRows(Element table) {
    final bodies = table.children.where((e) => e.localName == 'tbody').toList();
    final containers = bodies.isEmpty ? [table] : bodies;
    return [
      for (final c in containers)
        ...c.children.where((e) => e.localName == 'tr')
    ];
  }
}

/// One test from the Academia `Test Performance` table.
class AcademiaMarkTest {
  final String testName;
  final String scored;
  final String maxMarks;

  const AcademiaMarkTest({
    required this.testName,
    required this.scored,
    required this.maxMarks,
  });

  Map<String, String> toJson() => {
        'testName': testName,
        'scored': scored,
        'maxMarks': maxMarks,
      };
}

/// One course row from the Academia `Test Performance` table.
class AcademiaMarkRecord {
  final String courseCode;
  final String courseType;
  final List<AcademiaMarkTest> tests;

  const AcademiaMarkRecord({
    required this.courseCode,
    required this.courseType,
    required this.tests,
  });
}
