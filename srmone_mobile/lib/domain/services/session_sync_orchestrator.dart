// lib/domain/services/session_sync_orchestrator.dart
// 4-Layer "Zero-Logout" Academia sync orchestrator.
// Specification: architecture.md §5, plan.md Phase 3.
//
// Layer 1: Stale-While-Revalidate (SWR) — UI renders cached Drift SQLite stream at 0ms.
// Layer 2: Cache-Busting — GET requests append ?_t=<epoch_ms> and no-cache headers.
// Layer 3: Silent Re-Auth — If session returns 401/403/signin redirect, re-authenticates
//          using SecureVault credentials, updates cookies, and retries seamlessly.
// Layer 4: Dual-Source Reconciliation — Compares Academia and Student Portal hoursConducted.
//
// One sync refreshes attendance, student profile, internal marks, timetable
// and the academic calendar. Attendance is required; the other sections are
// best-effort so a failure in one never discards the rest.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/network/simple_cookie_jar.dart';
import '../../core/security/secure_vault_service.dart';
import '../../scrapers/academia/academia_client.dart';
import '../../scrapers/academia/academia_parsers.dart';
import '../../scrapers/student_portal/sp_client.dart';
import 'attendance_planner_math.dart';
import 'calendar_day_resolver.dart';
import 'notification_rule_engine.dart';

/// Asks the user to read a Student Portal CAPTCHA image. Returns the typed
/// text, or null if the user cancelled.
typedef SpCaptchaPrompt = Future<String?> Function(Uint8List captchaImage);

enum SyncStatus { idle, syncing, success, reauthenticated, error }

class SyncResult {
  final SyncStatus status;
  final int subjectsUpdated;
  final bool sessionWasRefreshed;
  final String? errorMessage;

  const SyncResult({
    required this.status,
    required this.subjectsUpdated,
    required this.sessionWasRefreshed,
    this.errorMessage,
  });
}

/// The semester ('odd' | 'even') whose calendar applies on [date].
/// SRM odd semesters run July–December, even semesters January–June.
String semesterFor(DateTime date) => date.month >= 7 ? 'odd' : 'even';

/// Converts parser calendar months (raw day-of-month `date` cells) into the
/// stored shape whose `date` is a local `YYYY-MM-DD` key. Months whose header
/// can't be parsed into a month and year are dropped.
List<Map<String, dynamic>> normalizeCalendarMonths(
    List<Map<String, dynamic>> months) {
  final out = <Map<String, dynamic>>[];
  for (final m in months) {
    final name = m['month']?.toString() ?? '';
    final start = CalendarDayResolver.parseMonthName(name);
    if (start == null) continue;
    final days = <Map<String, String>>[];
    for (final d in (m['days'] as List).cast<Map<String, dynamic>>()) {
      final dayNum = int.tryParse(d['date']?.toString().trim() ?? '');
      if (dayNum == null || dayNum < 1 || dayNum > 31) continue;
      final date = DateTime(start.year, start.month, dayNum);
      if (date.month != start.month) continue;
      days.add({
        'date': CalendarDayResolver.localDateKey(date),
        'day': d['day']?.toString() ?? '',
        'event': d['event']?.toString() ?? '',
        'dayOrder': d['dayOrder']?.toString() ?? '',
      });
    }
    out.add({'month': name, 'days': days});
  }
  return out;
}

/// Turns a network or parsing error into a message a student can act on.
String friendlySyncError(Object e) {
  if (e is DioException || e is SocketException || e is HandshakeException) {
    return "Couldn't reach SRM Academia. Check your internet connection and try again.";
  }
  if (e is FormatException) {
    return 'SRM Academia returned a page SRM One could not read. Try again later.';
  }
  return 'Something went wrong while syncing. Try again later.';
}

class SessionSyncOrchestrator {
  final AppDatabase _db;
  final SecureVaultService _vault;
  final NotificationRuleEngine _notifEngine;

  SessionSyncOrchestrator({
    required AppDatabase db,
    required SecureVaultService vault,
    required NotificationRuleEngine notifEngine,
  })  : _db = db,
        _vault = vault,
        _notifEngine = notifEngine;

  /// Main sync method.
  ///
  /// 1. Reads stored credentials & cookie jar from Hardware Vault.
  /// 2. Fetches the My_Time_Table page with cache-busting headers.
  /// 3. If Zoho session expired / invalid, triggers silent re-login with vault credentials.
  /// 4. Parses attendance, profile, marks and the course list from that page,
  ///    then fetches the unified timetable grid and the academic calendar.
  /// 5. Optionally reconciles with Student Portal if an SP password or cookies
  ///    exist. [onSpCaptcha] lets a foreground caller ask the user to solve a
  ///    CAPTCHA when on-device OCR fails; background syncs pass null.
  /// 6. Persists everything to Drift and runs the notification rules.
  Future<SyncResult> syncAll({
    bool forceFreshLogin = false,
    SpCaptchaPrompt? onSpCaptcha,
  }) async {
    final email = await _vault.getAcademiaEmail();
    final password = await _vault.getAcademiaPassword();

    if (email == null || email.isEmpty) {
      return const SyncResult(
        status: SyncStatus.error,
        subjectsUpdated: 0,
        sessionWasRefreshed: false,
        errorMessage: 'No authenticated user found in secure vault',
      );
    }

    // Restore or create cookie jar
    final savedCookiesJson = await _vault.getAcademiaCookiesJson();
    final cookieJar = savedCookiesJson != null && savedCookiesJson.isNotEmpty
        ? SimpleCookieJar.fromJson(savedCookiesJson)
        : SimpleCookieJar();

    final academiaClient = AcademiaClient(cookieJar: cookieJar);
    bool sessionRefreshed = false;
    String pageHtml;

    try {
      // Force fresh login requested (first sign-in or pull-to-refresh)
      if (forceFreshLogin && password != null && password.isNotEmpty) {
        final loginOk = await academiaClient.login(email, password);
        if (!loginOk) return _error('Incorrect NetID or password.');
        await _vault.saveAcademiaCookies(cookieJar.toJson());
        sessionRefreshed = true;
      }

      try {
        pageHtml = await academiaClient.fetchAttendancePage();
      } on SessionExpiredException catch (_) {
        // Layer 3: Silent Background Cookie Rotation
        if (password == null || password.isEmpty) {
          return _error('Your session expired. Sign in again.');
        }
        final reauthOk = await academiaClient.login(email, password);
        if (!reauthOk) return _error('Incorrect NetID or password.');
        await _vault.saveAcademiaCookies(cookieJar.toJson());
        sessionRefreshed = true;
        try {
          pageHtml = await academiaClient.fetchAttendancePage();
        } on SessionExpiredException catch (_) {
          return _error(
              "Couldn't sign in to SRM Academia. Check your NetID and password.");
        }
      }
    } catch (e) {
      return _error(friendlySyncError(e));
    }

    List<AttendanceInput> records;
    try {
      records = AcademiaParsers.parseAttendance(pageHtml);
    } catch (e) {
      return _error(friendlySyncError(e));
    }

    // Save cookie jar state after successful operations
    await _vault.saveAcademiaCookies(cookieJar.toJson());

    // Best-effort sections from the same page and two extra page fetches.
    final profile = await _guard(() => _syncProfile(email, pageHtml)) ?? {};
    await _guard(() => _syncAcademiaMarks(email, pageHtml, records));
    await _guard(() =>
        _syncTimetable(email, pageHtml, profile['Batch'], academiaClient));
    await _guard(() => _syncCalendars(email, academiaClient));

    // Layer 4: Dual-Source Reconciliation with Student Portal (if configured)
    final spRecords = await _guard(
        () => _syncStudentPortal(email, records, onSpCaptcha: onSpCaptcha));
    if (spRecords != null && spRecords.isNotEmpty) {
      records = reconcileAttendance(records, spRecords);
    }

    // Persist to SQLite (Drift)
    if (records.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final companions = records.map((r) {
        return AttendanceCacheCompanion(
          academiaEmail: drift.Value(email),
          courseCode: drift.Value(r.courseCode),
          courseTitle: drift.Value(r.courseTitle),
          category: drift.Value(r.category),
          facultyName: drift.Value(r.facultyName),
          slot: drift.Value(r.slot),
          roomNo: drift.Value(r.roomNo),
          hoursConducted: drift.Value(r.hoursConducted),
          hoursAbsent: drift.Value(r.hoursAbsent),
          attendancePct: drift.Value(r.attendancePct),
          source: const drift.Value('academia'),
          updatedAt: drift.Value(now),
        );
      }).toList();

      await _db.replaceAttendanceRecords(email, companions);

      // Upsert daily snapshot
      await _notifEngine.upsertDailySnapshot(email, records);

      // Low attendance alerts: enabled unless the user turned them off; the
      // threshold is the one the Settings slider writes.
      final notifSettings = await _db.watchNotificationSettings(email).first;
      final userSettings = await _db.watchUserSettings(email).first;
      final alertEnabled = (notifSettings?.attendanceAlertEnabled ?? 1) == 1;
      final threshold = userSettings?.attendanceThreshold ?? 75.0;

      await _notifEngine.maybeNotifyLowAttendance(
        email,
        records,
        threshold: threshold,
        alertEnabled: alertEnabled,
      );

      // Check welcome notification rule
      await _notifEngine.maybeNotifyWelcome(email);
    }

    return SyncResult(
      status:
          sessionRefreshed ? SyncStatus.reauthenticated : SyncStatus.success,
      subjectsUpdated: records.length,
      sessionWasRefreshed: sessionRefreshed,
    );
  }

  SyncResult _error(String message) => SyncResult(
        status: SyncStatus.error,
        subjectsUpdated: 0,
        sessionWasRefreshed: false,
        errorMessage: message,
      );

  /// Runs a best-effort section; a failure leaves the cached data untouched.
  Future<T?> _guard<T>(Future<T> Function() section) async {
    try {
      return await section();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> _syncProfile(String email, String html) async {
    final info = AcademiaParsers.parseStudentProfile(html);
    if (info.isEmpty) return info;
    String v(List<String> keys) {
      for (final k in keys) {
        final value = info[k];
        if (value != null && value.isNotEmpty) return value;
      }
      return '';
    }

    await _db.upsertStudentProfile(StudentProfilesCompanion(
      academiaEmail: drift.Value(email),
      name: drift.Value(v(['Name', 'Student Name', 'name'])),
      regNumber: drift.Value(v(['Registration Number'])),
      branch: drift.Value(v(['Specialization', 'Department'])),
      section: drift.Value(v(['Section'])),
      semester: drift.Value(v(['Semester'])),
      batch: drift.Value(v(['Batch'])),
      program: drift.Value(v(['Program'])),
      rawDataJson: drift.Value(jsonEncode(info)),
      cachedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
    ));
    return info;
  }

  Future<void> _syncAcademiaMarks(
      String email, String html, List<AttendanceInput> attendance) async {
    final marks = AcademiaParsers.parseMarks(html);
    if (marks.isEmpty) return;
    final titles = {for (final a in attendance) a.courseCode: a.courseTitle};
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.replaceMarksRecords(email, 'academia', [
      for (final m in marks)
        MarksCacheCompanion(
          academiaEmail: drift.Value(email),
          courseCode: drift.Value(m.courseCode),
          courseTitle: drift.Value(titles[m.courseCode] ?? ''),
          courseType: drift.Value(m.courseType),
          source: const drift.Value('academia'),
          testsJson:
              drift.Value(jsonEncode(m.tests.map((t) => t.toJson()).toList())),
          updatedAt: drift.Value(now),
        ),
    ]);
  }

  Future<void> _syncTimetable(
      String email, String html, String? batch, AcademiaClient client) async {
    final rawCourses = AcademiaParsers.parseTimetableCourses(html);
    if (rawCourses.isEmpty) return;
    final effectiveBatch =
        (batch == null || batch.trim().isEmpty) ? '1' : batch.trim();
    final slotMap = await client.fetchUnifiedSlotMap(effectiveBatch);
    if (slotMap.isEmpty) return;
    final courses = AcademiaParsers.mergeTimetable(rawCourses, slotMap);
    await _db.upsertTimetable(TimetableCacheCompanion(
      academiaEmail: drift.Value(email),
      batch: drift.Value(effectiveBatch),
      coursesJson: drift.Value(jsonEncode(courses)),
      advisorsJson:
          drift.Value(jsonEncode(AcademiaParsers.parseAdvisors(html))),
      updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Refreshes the current semester's calendar every sync, and the other
  /// semester only until it has been cached once.
  Future<void> _syncCalendars(String email, AcademiaClient client) async {
    final current = semesterFor(DateTime.now());
    final other = current == 'odd' ? 'even' : 'odd';
    final sems = [
      current,
      if (await _db.getCalendar(email, other) == null) other,
    ];
    for (final sem in sems) {
      final months = normalizeCalendarMonths(await client.fetchCalendar(sem));
      if (months.isEmpty) continue;
      await _db.upsertCalendar(CalendarCacheCompanion(
        academiaEmail: drift.Value(email),
        semester: drift.Value(sem),
        monthsJson: drift.Value(jsonEncode(months)),
        updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
      ));
    }
  }

  /// Signs in to the Student Portal when needed and returns its attendance.
  /// Also stores SP internal marks as a synthetic "Total (Internal)" test
  /// (Bug Fix #6). Returns null when the Student Portal isn't configured or
  /// can't be reached.
  Future<List<AttendanceInput>?> _syncStudentPortal(
    String email,
    List<AttendanceInput> academiaRecords, {
    SpCaptchaPrompt? onSpCaptcha,
  }) async {
    final spPassword = await _vault.getSpPassword();
    final spSavedCookies = await _vault.getSpCookiesJson();
    final hasPassword = spPassword != null && spPassword.isNotEmpty;
    if (!hasPassword && spSavedCookies == null) return null;

    final jar = spSavedCookies != null
        ? SimpleCookieJar.fromJson(spSavedCookies)
        : SimpleCookieJar();
    final client = SPClient(cookieJar: jar);

    List<AttendanceInput> spRecords = const [];
    if (spSavedCookies != null) {
      try {
        spRecords = await client.fetchAttendance();
      } catch (_) {
        spRecords = const [];
      }
    }

    if (spRecords.isEmpty) {
      if (!hasPassword) return null;
      final netId = email.split('@').first;
      var result = await client.login(netId, spPassword);
      for (int attempt = 0;
          attempt < 3 && result is SPCaptchaRequired && onSpCaptcha != null;
          attempt++) {
        final required = result;
        final typed = await onSpCaptcha(required.captchaImage);
        if (typed == null || typed.trim().isEmpty) return null;
        result = await client.submitLogin(
            required.context, netId, spPassword, typed.trim());
      }
      if (result is! SPLoginSuccess) return null;
      spRecords = await client.fetchAttendance();
    }

    await _vault.saveSpCookies(jar.toJson());

    try {
      final spMarks = await client.fetchInternalMarks();
      if (spMarks.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await _db.replaceMarksRecords(email, 'student_portal', [
          for (final m in spMarks)
            MarksCacheCompanion(
              academiaEmail: drift.Value(email),
              courseCode: drift.Value(m.courseCode),
              courseTitle: drift.Value(m.courseTitle),
              source: const drift.Value('student_portal'),
              testsJson: drift.Value(jsonEncode([
                {
                  'testName': 'Total (Internal)',
                  'scored': m.obtained,
                  'maxMarks': m.maxMark,
                  'source': 'student_portal',
                }
              ])),
              updatedAt: drift.Value(now),
            ),
        ]);
      }
    } catch (_) {
      // SP marks are optional.
    }

    return spRecords;
  }

  /// Layer 4: Reconciles records between Academia and Student Portal.
  /// If Student Portal reports higher hoursConducted for a courseCode, uses SP data.
  List<AttendanceInput> reconcileAttendance(
    List<AttendanceInput> academiaRecords,
    List<AttendanceInput> spRecords,
  ) {
    final spMap = {for (var r in spRecords) r.courseCode.toUpperCase(): r};
    final merged = <AttendanceInput>[];

    for (final acad in academiaRecords) {
      final sp = spMap[acad.courseCode.toUpperCase()];
      if (sp != null && sp.hoursConducted > acad.hoursConducted) {
        // Student Portal has newer attendance counts
        merged.add(
          AttendanceInput(
            courseCode: acad.courseCode,
            courseTitle:
                acad.courseTitle.isNotEmpty ? acad.courseTitle : sp.courseTitle,
            hoursConducted: sp.hoursConducted,
            hoursAbsent: sp.hoursAbsent,
            attendancePct: sp.attendancePct,
            category: acad.category,
            facultyName: acad.facultyName,
            slot: acad.slot,
            roomNo: acad.roomNo,
          ),
        );
      } else {
        merged.add(acad);
      }
    }

    return merged;
  }
}
