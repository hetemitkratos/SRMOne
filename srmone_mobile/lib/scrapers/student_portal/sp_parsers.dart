// lib/scrapers/student_portal/sp_parsers.dart
// Parsers for SRM Student Portal (sp.srmist.edu.in) responses.
// Ported from academia-backend/academia-scraper/cmd/studentportal/parsers.go & marks.go

import 'package:html/parser.dart' as html_parser;
import '../../domain/services/attendance_planner_math.dart';

class SPSecureConfig {
  final String captchaText;
  final String captchaFieldName;
  final String domainFieldName;
  final String randomDelimiter;
  final String nonce;

  const SPSecureConfig({
    required this.captchaText,
    required this.captchaFieldName,
    required this.domainFieldName,
    required this.randomDelimiter,
    required this.nonce,
  });
}

class SPMarkRecord {
  final String courseCode;
  final String courseTitle;
  final String obtained;
  final String maxMark;

  /// The portal's subject id and status from the row's "View Details"
  /// button, used to fetch the component marks; null when absent.
  final String? subjectId;
  final String? status;

  const SPMarkRecord({
    required this.courseCode,
    required this.courseTitle,
    required this.obtained,
    required this.maxMark,
    this.subjectId,
    this.status,
  });
}

/// One component (FT-I, FT-II, …) of a course's internal marks, from the
/// portal's "View Details".
class SPMarkComponent {
  final String component;
  final String obtained;
  final String maxMark;

  /// When the mark was entered, as the portal shows it (01/Sep/2026).
  final String enteredOn;

  const SPMarkComponent({
    required this.component,
    required this.obtained,
    required this.maxMark,
    required this.enteredOn,
  });
}

class SPParsers {
  SPParsers._();

  // ─── 1. SECURE_CONFIG Parser ────────────────────────────────────────────────

  static SPSecureConfig parseSecureConfig(String html) {
    String extract(RegExp reg) => reg.firstMatch(html)?.group(1)?.trim() ?? '';

    final captchaText =
        extract(RegExp(r"SECURE_CONFIG\.captchaText\s*=\s*'([^']+)'"));
    final captchaFieldName =
        extract(RegExp(r"SECURE_CONFIG\.captchaFieldName\s*=\s*'([^']+)'"));
    final domainFieldName =
        extract(RegExp(r"SECURE_CONFIG\.domainFieldName\s*=\s*'([^']+)'"));
    final randomDelimiter =
        extract(RegExp(r"SECURE_CONFIG\.randomDelimiter\s*=\s*'([^']+)'"));
    final nonce = extract(RegExp(r"nonce\s*:\s*'([^']+)'"));

    return SPSecureConfig(
      captchaText: captchaText,
      captchaFieldName: captchaFieldName,
      domainFieldName: domainFieldName,
      randomDelimiter: randomDelimiter,
      nonce: nonce,
    );
  }

  // ─── 2. Honeypot Field Collector ────────────────────────────────────────────

  static List<String> extractHoneypotNames(String html) {
    final doc = html_parser.parse(html);
    final names = <String>[];
    for (final input in doc.querySelectorAll('input[name^=ph_]')) {
      final name = input.attributes['name']?.trim();
      if (name != null && name.isNotEmpty) {
        names.add(name);
      }
    }
    return names;
  }

  // ─── 2b. CAPTCHA Image URL ──────────────────────────────────────────────────

  /// Absolute URL of the real CAPTCHA image, from `img#secure_captcha`'s
  /// `data-src` (SCRAPER_SPEC.md §SP step 4). The portal only serves the image
  /// at this one-time `SCaptchaServlet?ts=…&token=…` URL; the bare servlet
  /// answers 403 with an empty body. Returns '' when the page has no image.
  static String extractCaptchaImageUrl(String html, String baseUrl) {
    final img = html_parser.parse(html).querySelector('img#secure_captcha');
    final src = (img?.attributes['data-src'] ?? img?.attributes['src'] ?? '')
        .trim()
        .replaceAll('&amp;', '&');
    if (src.isEmpty || src.startsWith('data:')) return '';
    if (src.startsWith('http')) return src;
    return Uri.parse(baseUrl).resolve(src).toString();
  }

  /// Port of Go `isSPLoginFailed`. Success always lands on the HRDSystem
  /// dashboard; landing back on LoginServlet/youLogin.jsp means the portal
  /// rejected the attempt, whether or not it rendered an error alert.
  static bool isLoginFailed(String finalUrl, String body) {
    final location = finalUrl.toLowerCase();
    if (location.contains('hrdsystem')) return false;
    if (location.contains('loginservlet') ||
        location.contains('youlogin.jsp')) {
      return true;
    }
    final lower = body.toLowerCase();
    return lower.contains('alert-danger') &&
        (lower.contains('invalid credentials') ||
            lower.contains('invalid captcha') ||
            lower.contains('enter valid captcha') ||
            lower.contains('login failed') ||
            lower.contains('incorrect password') ||
            lower.contains('account locked'));
  }

  /// Text of the portal's `div.alert-danger` after a failed sign-in, with
  /// whitespace collapsed. Returns '' when there is no alert.
  static String extractAlertText(String html) {
    final alert = html_parser.parse(html).querySelector('div.alert-danger');
    if (alert == null) return '';
    final text = alert.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final joined = text.join(' ');
    return joined.length > 300 ? joined.substring(0, 300) : joined;
  }

  // ─── 3. Student Portal Attendance Parser ───────────────────────────────────

  /// Parses attendance records from studentAttendanceDetails.jsp (iden=9).
  /// Uses permissive column matching to handle portal variations.
  static List<AttendanceInput> parseAttendance(String html) {
    final doc = html_parser.parse(html);
    final tables = doc.querySelectorAll('table');
    final List<AttendanceInput> records = [];

    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      if (rows.length < 2) continue;

      // Extract header row
      final headers = rows.first
          .querySelectorAll('th, td')
          .map((e) => e.text.trim())
          .toList();

      final hasCode = headers.any((h) =>
          h.toLowerCase().contains('code') ||
          h.toLowerCase().contains('subject'));
      final hasAttn = headers.any((h) =>
          h.toLowerCase().contains('attn') ||
          h.toLowerCase().contains('percentage') ||
          h.toLowerCase().contains('hours'));

      if (!hasCode || !hasAttn) continue;

      // Map column indices
      int codeIdx = -1;
      int descIdx = -1;
      int maxHoursIdx = -1;
      int attHoursIdx = -1;
      int absentHoursIdx = -1;
      int pctIdx = -1;

      for (int i = 0; i < headers.length; i++) {
        final h = headers[i].toLowerCase();
        if (codeIdx < 0 && (h.contains('code') || h == 'code')) {
          codeIdx = i;
        }
        if (descIdx < 0 &&
            (h.contains('description') ||
                h.contains('title') ||
                h.contains('course'))) {
          descIdx = i;
        }
        if (maxHoursIdx < 0 && (h.contains('max') || h.contains('conducted'))) {
          maxHoursIdx = i;
        }
        if (attHoursIdx < 0 &&
            (h.contains('att.') ||
                h.contains('present') ||
                h == 'att. hours')) {
          attHoursIdx = i;
        }
        if (absentHoursIdx < 0 &&
            (h.contains('absent') || h == 'absent hours')) {
          absentHoursIdx = i;
        }
        if (pctIdx < 0 &&
            (h.contains('percentage') ||
                h.contains('%') ||
                h.contains('total percentage'))) {
          pctIdx = i;
        }
      }

      // Fallback column positions if headers aren't specifically labeled:
      // Typically: Code (0) | Description (1) | Max (2) | Att (3) | Absent (4) | Pct (5)
      if (codeIdx < 0) codeIdx = 0;
      if (descIdx < 0 && headers.length > 1) descIdx = 1;
      if (maxHoursIdx < 0 && headers.length > 2) maxHoursIdx = 2;
      if (attHoursIdx < 0 && headers.length > 3) attHoursIdx = 3;
      if (absentHoursIdx < 0 && headers.length > 4) absentHoursIdx = 4;
      if (pctIdx < 0 && headers.length > 5) pctIdx = 5;

      for (int r = 1; r < rows.length; r++) {
        final cells =
            rows[r].querySelectorAll('td').map((e) => e.text.trim()).toList();
        if (cells.length < 3) continue;

        final code = codeIdx < cells.length ? cells[codeIdx] : '';
        if (code.isEmpty || code.toLowerCase() == 'code') continue;

        final desc =
            descIdx >= 0 && descIdx < cells.length ? cells[descIdx] : '';
        final maxHStr = maxHoursIdx >= 0 && maxHoursIdx < cells.length
            ? cells[maxHoursIdx]
            : '0';
        final absentHStr = absentHoursIdx >= 0 && absentHoursIdx < cells.length
            ? cells[absentHoursIdx]
            : '0';
        final pctStr =
            pctIdx >= 0 && pctIdx < cells.length ? cells[pctIdx] : '';

        final conducted =
            int.tryParse(maxHStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final absent =
            int.tryParse(absentHStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
        final pct = double.tryParse(pctStr.replaceAll(RegExp(r'[^\d.]'), '')) ??
            (conducted > 0 ? ((conducted - absent) / conducted) * 100 : 0.0);

        records.add(
          AttendanceInput(
            courseCode: code,
            courseTitle: desc,
            hoursConducted: conducted,
            hoursAbsent: absent,
            attendancePct: pct,
          ),
        );
      }

      if (records.isNotEmpty) break;
    }

    return records;
  }

  // ─── 4. Student Portal Internal Marks Parser (iden=13) ──────────────────────

  /// Parses internal marks from studentInternalMarkDetails.jsp (iden=13).
  /// Code | Description | Mark / Max. Mark
  static List<SPMarkRecord> parseInternalMarks(String html) {
    final doc = html_parser.parse(html);
    final List<SPMarkRecord> out = [];
    final reSplit = RegExp(r'^\s*([0-9.]+)\s*/\s*([0-9.]+)\s*$');

    for (final table in doc.querySelectorAll('table')) {
      final headers = table
          .querySelectorAll('th')
          .map((e) => e.text.trim().toLowerCase())
          .toList();

      if (!headers.any((h) => h.contains('code')) ||
          !headers.any((h) => h.contains('mark'))) {
        continue;
      }

      for (final row in table.querySelectorAll('tr')) {
        final cells =
            row.querySelectorAll('td').map((e) => e.text.trim()).toList();
        if (cells.length < 3) continue;

        final code = cells[0];
        final title = cells[1];
        final markCell = cells[2];

        if (code.isEmpty || code.toLowerCase() == 'code') continue;

        String obtained = markCell;
        String maxMark = '';

        final match = reSplit.firstMatch(markCell);
        if (match != null) {
          obtained = match.group(1) ?? markCell;
          maxMark = match.group(2) ?? '';
        }

        final details = _viewDetails.firstMatch(row.innerHtml);
        out.add(
          SPMarkRecord(
            courseCode: code,
            courseTitle: title,
            obtained: obtained,
            maxMark: maxMark,
            subjectId: details?.group(1),
            status: details?.group(2),
          ),
        );
      }

      if (out.isNotEmpty) break;
    }

    return out;
  }

  /// `funViewComponentWiseMarks('42213', '21CSC403T', '...', 2)` → the
  /// subject id and status.
  static final _viewDetails = RegExp(
      r"""funViewComponentWiseMarks\(\s*'([^']*)'\s*,[^)]*?,\s*'?(\d+)'?\s*\)""");

  /// Parses studentInternalMarkDetailsInner.jsp (a course's "View Details"):
  /// Entered on | Component | Mark / Max. Mark.
  static List<SPMarkComponent> parseMarkComponents(String html) {
    final doc = html_parser.parse(html);
    final reSplit = RegExp(r'^\s*([0-9.]+)\s*/\s*([0-9.]+)\s*$');
    for (final table in doc.querySelectorAll('table')) {
      final headers = table
          .querySelectorAll('th')
          .map((e) => e.text.trim().toLowerCase())
          .toList();
      final comp = headers.indexWhere((h) => h.contains('component'));
      final mark = headers.indexWhere((h) => h.contains('mark'));
      if (comp < 0 || mark < 0) continue;
      final entered = headers.indexWhere((h) => h.contains('enter'));

      final out = <SPMarkComponent>[];
      for (final row in table.querySelectorAll('tr')) {
        final cells =
            row.querySelectorAll('td').map((e) => e.text.trim()).toList();
        if (cells.length <= comp || cells.length <= mark) continue;
        final name = cells[comp];
        if (name.isEmpty) continue;
        final m = reSplit.firstMatch(cells[mark]);
        out.add(SPMarkComponent(
          component: name,
          obtained: m?.group(1) ?? cells[mark],
          maxMark: m?.group(2) ?? '',
          enteredOn:
              entered >= 0 && entered < cells.length ? cells[entered] : '',
        ));
      }
      return out;
    }
    return const [];
  }

  // ─── 5. Student Portal Profile Parser ───────────────────────────────────────

  static Map<String, String> parseStudentProfile(String html) {
    final doc = html_parser.parse(html);
    final map = <String, String>{};

    for (final row in doc.querySelectorAll('tr')) {
      final cells = row.querySelectorAll('td, th');
      if (cells.length >= 2) {
        for (int i = 0; i < cells.length - 1; i += 2) {
          final k = cells[i].text.replaceAll(':', '').trim();
          final v = cells[i + 1].text.trim();
          if (k.isNotEmpty && v.isNotEmpty) {
            map[k] = v;
          }
        }
      }
    }

    return map;
  }
}
