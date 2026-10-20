// lib/domain/services/session_sync_orchestrator.dart
// 4-Layer "Zero-Logout" Academia sync orchestrator.
// Specification: architecture.md §5, plan.md Phase 3.
//
// Layer 1: Stale-While-Revalidate (SWR) — UI renders cached Drift SQLite stream at 0ms.
// Layer 2: Cache-Busting — GET requests append ?_t=<epoch_ms> and no-cache headers.
// Layer 3: Silent Re-Auth — If session returns 401/403/signin redirect, re-authenticates
//          using SecureVault credentials, updates cookies, and retries seamlessly.
// Layer 4: Attendance comes only from the Student Portal; Academia supplies
//          each course's details (faculty, slot, room, category).
//
// One sync refreshes the student profile, internal marks, the course list,
// timetable and academic calendar from Academia, and attendance from the
// Student Portal. The Academia page is required; the other sections are
// best-effort so a failure in one never discards the rest.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import '../../core/database/app_database.dart';
import '../../core/network/simple_cookie_jar.dart';
import '../../core/security/secure_vault_service.dart';
import '../../scrapers/academia/academia_client.dart';
import '../../scrapers/academia/academia_parsers.dart';
import '../../scrapers/student_portal/sp_client.dart';
import 'attendance_planner_math.dart';
import 'calendar_day_resolver.dart';
import 'notification_rule_engine.dart';
import 'timetable_schedule.dart';

/// Asks the user to read a Student Portal CAPTCHA image. Returns the typed
/// text, or null if the user cancelled.
typedef SpCaptchaPrompt = Future<String?> Function(Uint8List captchaImage);

/// The user-visible stages of a sync, in the order they run.
enum SyncStep {
  signingIn('Signing in to SRM Academia…'),
  fetchingAttendance('Syncing your courses…'),
  syncingDetails('Syncing marks, timetable and calendar…'),
  saving('Saving…'),
  studentPortal('Connecting to Student Portal…'),
  solvingCaptcha('Solving Student Portal CAPTCHA…');

  final String label;
  const SyncStep(this.label);
}

typedef SyncProgress = void Function(SyncStep step);

/// Outcome of [SessionSyncOrchestrator.connectStudentPortal].
class SpConnectResult {
  final bool connected;
  final String message;
  const SpConnectResult(this.connected, this.message);
}

/// A Student Portal problem with a message the user can act on.
class SpSyncException implements Exception {
  final String message;
  const SpSyncException(this.message);

  @override
  String toString() => 'SpSyncException: $message';
}

/// Time budgets. Every portal request also has Dio's 30 s connect/receive
/// timeouts; these bound whole multi-request steps.
class SyncTimeouts {
  SyncTimeouts._();
  static const academiaLogin = Duration(seconds: 90);
  static const academiaPage = Duration(seconds: 45);
  static const detailsSection = Duration(seconds: 60);
  static const studentPortalBackground = Duration(seconds: 90);

  /// The timetable grid and calendar change about once a semester, so a
  /// normal sync re-downloads them only when the cached copy is older than
  /// this (or when the caller passes `forceDetails`).
  static const detailsMaxAge = Duration(hours: 24);
}

/// [partial]: Academia failed (see [SyncResult.errorMessage]) but the
/// Student Portal attendance still refreshed.
enum SyncStatus { idle, syncing, success, reauthenticated, partial, error }

/// The parts of a sync whose outcome is recorded in the database (by name),
/// so screens can say which data is stale and why.
enum SyncSection {
  /// Signing in to Academia and fetching its course page.
  academia,
  profile,
  marks,
  timetable,
  calendar,

  /// Attendance, from the Student Portal.
  attendance,
  studentPortalMarks,
}

class SyncResult {
  final SyncStatus status;
  final int subjectsUpdated;
  final bool sessionWasRefreshed;

  /// Why the sync failed ([SyncStatus.error]) or what failed in a
  /// [SyncStatus.partial] sync.
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
  if (e is AcademiaLoginException) return e.userMessage;
  if (e is TimeoutException) {
    return 'SRM Academia is taking too long to respond. Try again in a minute.';
  }
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
  final Dio? _academiaDio;
  final SPClient Function(SimpleCookieJar jar) _spClient;

  /// [academiaDio] and [spClient] are only for tests (fake portals).
  SessionSyncOrchestrator({
    required AppDatabase db,
    required SecureVaultService vault,
    required NotificationRuleEngine notifEngine,
    Dio? academiaDio,
    SPClient Function(SimpleCookieJar jar)? spClient,
  })  : _db = db,
        _vault = vault,
        _notifEngine = notifEngine,
        _academiaDio = academiaDio,
        _spClient = spClient ?? ((jar) => SPClient(cookieJar: jar));

  /// The sync currently running, shared by every caller that asks for one
  /// while it runs (two screens refreshing, or a refresh during sign-in), so
  /// the portal is never signed in to twice at once.
  Future<SyncResult>? _inflight;

  /// The details (timetable, calendar) step of the sync in [_inflight].
  Future<void>? _inflightDetails;

  /// Whether a sync is running right now.
  bool get isSyncing => _inflight != null;

  /// Main sync method.
  ///
  /// 1. Reads stored credentials & cookie jar from Hardware Vault.
  /// 2. Fetches the My_Time_Table page with cache-busting headers.
  /// 3. If Zoho session expired / invalid, triggers silent re-login with vault credentials.
  /// 4. Parses the profile, marks and course list from that page in one
  ///    background-isolate pass and saves them straight away. Academia's
  ///    page has no attendance hours, so attendance is never taken from it.
  /// 5. Fetches the unified timetable grid and the academic calendar in
  ///    parallel. With [waitForDetails] false the returned future completes
  ///    as soon as step 4 is saved and this step finishes in the background
  ///    (the screens update from the database when it lands).
  /// 6. Saves the Student Portal's attendance if an SP password or cookies
  ///    exist. [onSpCaptcha] lets a foreground caller ask the user to solve a
  ///    CAPTCHA when on-device OCR fails; background syncs pass null.
  ///    With [includeStudentPortal] false this step is skipped, so the
  ///    caller can run [connectStudentPortal] separately without making the
  ///    Academia sign-in wait for it.
  ///
  /// A call made while another sync is running joins that sync instead of
  /// starting a second one, unless [forceFreshLogin] is set.
  ///
  /// [onProgress] is told when each [SyncStep] starts.
  Future<SyncResult> syncAll({
    bool forceFreshLogin = false,
    SpCaptchaPrompt? onSpCaptcha,
    SyncProgress? onProgress,
    bool includeStudentPortal = true,
    bool waitForDetails = true,
    bool forceDetails = false,
  }) async {
    final running = _inflight;
    if (running != null && !forceFreshLogin) {
      _log('joining the sync already in progress');
      final result = await running;
      if (waitForDetails) await _inflightDetails;
      return result;
    }

    final details = Completer<void>();
    final run = _runSync(
      forceFreshLogin: forceFreshLogin,
      onSpCaptcha: onSpCaptcha,
      onProgress: onProgress,
      includeStudentPortal: includeStudentPortal,
      forceDetails: forceDetails,
      details: details,
    );
    _inflight = run;
    _inflightDetails = details.future;
    // The sync counts as running until its background details finish too.
    unawaited(details.future.whenComplete(() {
      if (identical(_inflight, run)) {
        _inflight = null;
        _inflightDetails = null;
      }
    }));
    final result = await run;
    if (waitForDetails) await details.future;
    return result;
  }

  Future<SyncResult> _runSync({
    required bool forceFreshLogin,
    required SpCaptchaPrompt? onSpCaptcha,
    required SyncProgress? onProgress,
    required bool includeStudentPortal,
    required bool forceDetails,
    required Completer<void> details,
  }) async {
    try {
      return await _sync(
        forceFreshLogin: forceFreshLogin,
        onSpCaptcha: onSpCaptcha,
        onProgress: onProgress,
        includeStudentPortal: includeStudentPortal,
        forceDetails: forceDetails,
        details: details,
      );
    } finally {
      // Error paths return before the details step starts.
      if (!details.isCompleted) details.complete();
    }
  }

  Future<SyncResult> _sync({
    required bool forceFreshLogin,
    required SpCaptchaPrompt? onSpCaptcha,
    required SyncProgress? onProgress,
    required bool includeStudentPortal,
    required bool forceDetails,
    required Completer<void> details,
  }) async {
    final total = Stopwatch()..start();
    void step(SyncStep s) {
      _log('${s.name} (+${total.elapsedMilliseconds} ms)');
      onProgress?.call(s);
    }

    final (email, password, savedCookiesJson) = await (
      _vault.getAcademiaEmail(),
      _vault.getAcademiaPassword(),
      _vault.getAcademiaCookiesJson(),
    ).wait;

    if (email == null || email.isEmpty) {
      return const SyncResult(
        status: SyncStatus.error,
        subjectsUpdated: 0,
        sessionWasRefreshed: false,
        errorMessage: 'No authenticated user found in secure vault',
      );
    }

    // Restore or create cookie jar. A forced sign-in clears it anyway.
    final cookieJar = !forceFreshLogin &&
            savedCookiesJson != null &&
            savedCookiesJson.isNotEmpty
        ? SimpleCookieJar.fromJson(savedCookiesJson)
        : SimpleCookieJar();

    final academiaClient =
        AcademiaClient(cookieJar: cookieJar, dio: _academiaDio);
    bool sessionRefreshed = false;
    AcademiaPageData? page;
    String? academiaError;

    Future<bool> signIn() {
      step(SyncStep.signingIn);
      return academiaClient
          .login(email, password!)
          .timeout(SyncTimeouts.academiaLogin);
    }

    Future<AcademiaPageData> fetchPage() {
      step(SyncStep.fetchingAttendance);
      return academiaClient
          .fetchAttendancePageData()
          .timeout(SyncTimeouts.academiaPage);
    }

    try {
      // Force fresh login requested (first sign-in)
      if (forceFreshLogin && password != null && password.isNotEmpty) {
        final loginOk = await signIn();
        if (!loginOk) return _error('Incorrect NetID or password.');
        await _saveCookies(cookieJar);
        sessionRefreshed = true;
      }

      try {
        page = await fetchPage();
      } on SessionExpiredException catch (_) {
        // Layer 3: Silent Background Cookie Rotation
        if (password == null || password.isEmpty) {
          academiaError = 'Your session expired. Sign in again.';
        } else if (!await signIn()) {
          academiaError = 'Incorrect NetID or password.';
        } else {
          await _saveCookies(cookieJar);
          sessionRefreshed = true;
          try {
            page = await fetchPage();
          } on SessionExpiredException catch (_) {
            academiaError = "Couldn't sign in to SRM Academia. "
                'Check your NetID and password.';
          }
        }
      }
    } catch (e) {
      _log('academia failed after ${total.elapsedMilliseconds} ms: '
          '${e.runtimeType}');
      academiaError = friendlySyncError(e);
    }

    if (page == null) {
      final message = academiaError ?? friendlySyncError(Object());
      await _recordOutcome(email, SyncSection.academia, error: message);
      // A first sign-in must fail here. Otherwise attendance, which comes
      // only from the Student Portal, can still refresh with the cached
      // course details.
      if (forceFreshLogin || !includeStudentPortal) return _error(message);
      final subjects = await _syncAttendance(email,
          step: step, onSpCaptcha: onSpCaptcha, onProgress: onProgress);
      _log('sync done without academia in ${total.elapsedMilliseconds} ms');
      return SyncResult(
        status: subjects > 0 ? SyncStatus.partial : SyncStatus.error,
        subjectsUpdated: subjects,
        sessionWasRefreshed: false,
        errorMessage: message,
      );
    }
    await _recordOutcome(email, SyncSection.academia);
    final AcademiaPageData academiaPage = page;

    // The page's course rows carry each course's details but no hours.
    final courses = academiaPage.attendance;
    _courseDetailsFromSync = {for (final c in courses) _courseKey(c): c};

    // Save cookie jar state after successful operations
    await _saveCookies(cookieJar);

    // Save everything the page carried first, so the dashboard can open on
    // it while the timetable grid and calendar download.
    step(SyncStep.saving);
    await _guard('profile', () => _syncProfile(email, academiaPage.profile),
        section: SyncSection.profile, email: email);
    await _guard(
        'marks', () => _syncAcademiaMarks(email, academiaPage, courses),
        section: SyncSection.marks, email: email);
    _log('academia saved in ${total.elapsedMilliseconds} ms');

    // Best-effort sections that need more page fetches, run in parallel.
    step(SyncStep.syncingDetails);
    final detailsWork = Future.wait([
      _guard(
          'timetable',
          () =>
              _syncTimetable(email, academiaPage, academiaClient, forceDetails),
          section: SyncSection.timetable,
          email: email),
      _guard(
          'calendar', () => _syncCalendars(email, academiaClient, forceDetails),
          section: SyncSection.calendar, email: email),
    ]).then((_) async {
      await _saveCookies(cookieJar);
      _log('details done in ${total.elapsedMilliseconds} ms');
    }).catchError((Object e) {
      _log('details failed: ${e.runtimeType}');
    });

    var subjectsUpdated = 0;
    if (includeStudentPortal) {
      // Layer 4: attendance from the Student Portal, while the details
      // download.
      subjectsUpdated = await _syncAttendance(email,
          step: step, onSpCaptcha: onSpCaptcha, onProgress: onProgress);
      _log('student portal step done in ${total.elapsedMilliseconds} ms');
    }
    details.complete(detailsWork);
    _log('sync done in ${total.elapsedMilliseconds} ms');

    return SyncResult(
      status:
          sessionRefreshed ? SyncStatus.reauthenticated : SyncStatus.success,
      subjectsUpdated: subjectsUpdated,
      sessionWasRefreshed: sessionRefreshed,
    );
  }

  /// Layer 4: refreshes attendance from the Student Portal (if configured)
  /// and saves it with each course's details. Returns the number of
  /// subjects saved; never throws.
  Future<int> _syncAttendance(
    String email, {
    required void Function(SyncStep) step,
    required SpCaptchaPrompt? onSpCaptcha,
    required SyncProgress? onProgress,
  }) async {
    step(SyncStep.studentPortal);
    final spRecords = await _guard(
        'student portal',
        () => _syncStudentPortal(email,
            onSpCaptcha: onSpCaptcha, onProgress: onProgress),
        timeout:
            onSpCaptcha == null ? SyncTimeouts.studentPortalBackground : null,
        section: SyncSection.attendance,
        email: email,
        recordWhen: (records) => records != null);
    if (spRecords == null || spRecords.isEmpty) return 0;
    await _persistAttendance(
        email, withCourseDetails(spRecords, await _courseDetails(email)));
    return spRecords.length;
  }

  /// Saves how [section] went; never throws.
  Future<void> _recordOutcome(String email, SyncSection section,
      {String? error}) async {
    try {
      await _db.recordSyncOutcome(email, section.name, error: error);
    } catch (e) {
      _log('could not record ${section.name}: ${e.runtimeType}');
    }
  }

  Future<void> _saveCookies(SimpleCookieJar jar) =>
      _vault.saveAcademiaCookies(jar.toJson());

  /// Whether the Student Portal has a saved password or session to refresh.
  Future<bool> isStudentPortalConfigured() async {
    final (password, cookies) =
        await (_vault.getSpPassword(), _vault.getSpCookiesJson()).wait;
    return (password != null && password.isNotEmpty) ||
        (cookies != null && cookies.isNotEmpty);
  }

  /// When [email]'s data was last synced (the newer of the Academia profile
  /// and the Student Portal attendance), or null if never.
  Future<DateTime?> lastSyncedAt(String email) async {
    final (attendanceMs, profile) = await (
      _db.lastAttendanceUpdate(email),
      _db.getStudentProfile(email),
    ).wait;
    final profileMs = profile?.cachedAt ?? 0;
    final ms = [attendanceMs ?? 0, profileMs].reduce((a, b) => a > b ? a : b);
    return ms == 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Signs in to the Student Portal (solving its CAPTCHA on-device, asking
  /// [onSpCaptcha] only if that fails), saves its attendance with each
  /// course's Academia details and stores its internal marks. Never throws.
  ///
  /// With [required] false a saved Student Portal session is reused even
  /// when no password is stored.
  Future<SpConnectResult> connectStudentPortal({
    SpCaptchaPrompt? onSpCaptcha,
    SyncProgress? onProgress,
    bool required = true,
  }) async {
    final sw = Stopwatch()..start();
    onProgress?.call(SyncStep.studentPortal);
    String? email;
    Future<SpConnectResult> failed(String message) async {
      final signedIn = email;
      if (signedIn != null && signedIn.isNotEmpty) {
        await _recordOutcome(signedIn, SyncSection.attendance, error: message);
      }
      return SpConnectResult(false, message);
    }

    try {
      email = await _vault.getAcademiaEmail();
      if (email == null || email.isEmpty) {
        return const SpConnectResult(false, 'Sign in to Academia first.');
      }
      final spRecords = await _syncStudentPortal(email,
          onSpCaptcha: onSpCaptcha, onProgress: onProgress, required: required);
      if (spRecords == null) {
        return const SpConnectResult(
            false, 'Add your Student Portal password first.');
      }
      await _recordOutcome(email, SyncSection.attendance);
      // Use the course details of an Academia sync that is still running.
      await _inflight?.catchError((Object _) => _error(''));
      if (spRecords.isNotEmpty) {
        await _persistAttendance(
            email, withCourseDetails(spRecords, await _courseDetails(email)));
        _log('student portal attendance saved in ${sw.elapsedMilliseconds} ms');
      }
      _log('student portal connected in ${sw.elapsedMilliseconds} ms');
      return SpConnectResult(
          true, 'Student Portal connected (${spRecords.length} subjects).');
    } on SpSyncException catch (e) {
      _log('student portal: ${e.message}');
      return failed(e.message);
    } on TimeoutException {
      return failed('Student Portal is taking too long to respond.');
    } on DioException {
      return failed(
          "Couldn't reach the Student Portal. Check your connection.");
    } catch (e) {
      final detail = e.toString();
      _log('student portal failed: ${e.runtimeType}: '
          '${detail.length > 300 ? detail.substring(0, 300) : detail}');
      return failed("Couldn't connect to the Student Portal. Try again later.");
    }
  }

  /// Course details from this run's latest Academia sync, by [_courseKey].
  Map<String, AttendanceInput> _courseDetailsFromSync = const {};

  static String _courseKey(AttendanceInput c) =>
      c.courseCode.trim().toUpperCase();

  /// Each course's details (title, category, faculty, slot, room) by
  /// [_courseKey]: the saved attendance rows, overridden by the cached
  /// timetable course list, overridden by this run's Academia sync.
  Future<Map<String, AttendanceInput>> _courseDetails(String email) async {
    final (saved, timetable) = await (
      _db.watchAttendanceRecords(email).first,
      _db.getTimetable(email),
    ).wait;
    return {
      for (final c in saved)
        c.courseCode.trim().toUpperCase(): AttendanceInput(
          courseCode: c.courseCode,
          courseTitle: c.courseTitle,
          hoursConducted: 0,
          hoursAbsent: 0,
          attendancePct: 0,
          category: c.category,
          facultyName: c.facultyName,
          slot: c.slot,
          roomNo: c.roomNo,
        ),
      for (final c in TimetableSchedule.parseCourses(timetable?.coursesJson))
        if ((c['courseCode']?.toString().trim() ?? '').isNotEmpty)
          c['courseCode'].toString().trim().toUpperCase(): AttendanceInput(
            courseCode: c['courseCode'].toString().trim(),
            courseTitle: c['courseTitle']?.toString() ?? '',
            hoursConducted: 0,
            hoursAbsent: 0,
            attendancePct: 0,
            category: c['category']?.toString() ?? '',
            facultyName: c['facultyName']?.toString() ?? '',
            slot: c['slot']?.toString() ?? '',
            roomNo: c['roomNo']?.toString() ?? '',
          ),
      ..._courseDetailsFromSync,
    };
  }

  /// Replaces the cached attendance and runs the snapshot and notification
  /// rules for it.
  Future<void> _persistAttendance(
      String email, List<AttendanceInput> records) async {
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
          source: const drift.Value('student_portal'),
          updatedAt: drift.Value(now),
        );
      }).toList();

      await _db.replaceAttendanceRecords(email, companions);

      // The trend snapshot and notification rules are extras: a failure in
      // them must not fail the sync (or a first sign-in) after the
      // attendance itself has been saved.
      await _guard('daily snapshot',
          () => _notifEngine.upsertDailySnapshot(email, records));

      await _guard('notification rules', () async {
        // Low attendance alerts: enabled unless the user turned them off;
        // the threshold is the one the Settings slider writes.
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
      });
    }
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[Sync] $message');
  }

  SyncResult _error(String message) => SyncResult(
        status: SyncStatus.error,
        subjectsUpdated: 0,
        sessionWasRefreshed: false,
        errorMessage: message,
      );

  /// Runs a best-effort section; a failure or a section that overruns
  /// [timeout] leaves the cached data untouched. A null [timeout] means no
  /// limit (used when the user may be typing a CAPTCHA).
  ///
  /// With a [section] (and the student's [email]) the outcome is saved for
  /// the screens: success when [recordWhen] accepts the value (always, if
  /// null), and the failure's user-facing reason otherwise.
  Future<T?> _guard<T>(String name, Future<T> Function() body,
      {Duration? timeout = SyncTimeouts.detailsSection,
      SyncSection? section,
      String? email,
      bool Function(T value)? recordWhen}) async {
    final sw = Stopwatch()..start();
    try {
      final future = body();
      final value = await (timeout == null ? future : future.timeout(timeout));
      _log('$name ok in ${sw.elapsedMilliseconds} ms');
      if (section != null &&
          email != null &&
          (recordWhen == null || recordWhen(value))) {
        await _recordOutcome(email, section);
      }
      return value;
    } catch (e) {
      _log('$name skipped after ${sw.elapsedMilliseconds} ms: '
          '${e is SpSyncException ? e.message : e.runtimeType}');
      if (section != null && email != null) {
        await _recordOutcome(email, section, error: _sectionError(e));
      }
      return null;
    }
  }

  /// A short reason a best-effort section failed, for the screens.
  static String _sectionError(Object e) => switch (e) {
        SpSyncException(:final message) => message,
        TimeoutException() => 'Took too long to respond.',
        DioException() || SocketException() => "Couldn't connect.",
        _ => "Couldn't read this from SRM.",
      };

  Future<void> _syncProfile(String email, Map<String, String> info) async {
    if (info.isEmpty) return;
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
  }

  Future<void> _syncAcademiaMarks(String email, AcademiaPageData page,
      List<AttendanceInput> attendance) async {
    final marks = page.marks;
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

  static bool _isFresh(int? updatedAtMs) =>
      updatedAtMs != null &&
      DateTime.now()
              .difference(DateTime.fromMillisecondsSinceEpoch(updatedAtMs)) <
          SyncTimeouts.detailsMaxAge;

  Future<void> _syncTimetable(String email, AcademiaPageData page,
      AcademiaClient client, bool force) async {
    final rawCourses = page.courses;
    if (rawCourses.isEmpty) return;
    final batch = page.profile['Batch'];
    final effectiveBatch =
        (batch == null || batch.trim().isEmpty) ? '1' : batch.trim();
    if (!force) {
      final cached = await _db.getTimetable(email);
      if (cached != null &&
          cached.batch == effectiveBatch &&
          _isFresh(cached.updatedAt)) {
        _log('timetable cached, skipping the grid download');
        return;
      }
    }
    final slotMap = await client.fetchUnifiedSlotMap(effectiveBatch);
    if (slotMap.isEmpty) return;
    final courses = AcademiaParsers.mergeTimetable(rawCourses, slotMap);
    await _db.upsertTimetable(TimetableCacheCompanion(
      academiaEmail: drift.Value(email),
      batch: drift.Value(effectiveBatch),
      coursesJson: drift.Value(jsonEncode(courses)),
      advisorsJson: drift.Value(jsonEncode(page.advisors)),
      updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Refreshes the current semester's calendar when it is missing, older
  /// than [SyncTimeouts.detailsMaxAge] or [force]d. The other semester is
  /// tried alongside it until it has been cached once (it is often not
  /// published yet, so it must not trigger a download on its own).
  Future<void> _syncCalendars(
      String email, AcademiaClient client, bool force) async {
    final current = semesterFor(DateTime.now());
    final other = current == 'odd' ? 'even' : 'odd';
    final cached = await _db.getCalendar(email, current);
    if (!force && cached != null && _isFresh(cached.updatedAt)) {
      _log('calendar cached, skipping the download');
      return;
    }
    final sems = [
      current,
      if (await _db.getCalendar(email, other) == null) other,
    ];
    await Future.wait([
      for (final sem in sems)
        client.fetchCalendar(sem).then((raw) async {
          final months = normalizeCalendarMonths(raw);
          if (months.isEmpty) return;
          await _db.upsertCalendar(CalendarCacheCompanion(
            academiaEmail: drift.Value(email),
            semester: drift.Value(sem),
            monthsJson: drift.Value(jsonEncode(months)),
            updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
          ));
        }),
    ]);
  }

  /// Signs in to the Student Portal when needed and returns its attendance.
  /// Also stores SP internal marks as a synthetic "Total (Internal)" test
  /// (Bug Fix #6). Returns null when the Student Portal isn't configured;
  /// throws [SpSyncException] with a user-facing reason when sign-in fails.
  /// With [required] false (background sync) a portal that needs a CAPTCHA
  /// nobody can type is reported the same way.
  Future<List<AttendanceInput>?> _syncStudentPortal(
    String email, {
    SpCaptchaPrompt? onSpCaptcha,
    SyncProgress? onProgress,
    bool required = false,
  }) async {
    final spPassword = await _vault.getSpPassword();
    final spSavedCookies = await _vault.getSpCookiesJson();
    final hasPassword = spPassword != null && spPassword.isNotEmpty;
    if (!hasPassword && (spSavedCookies == null || required)) return null;

    final jar = spSavedCookies != null
        ? SimpleCookieJar.fromJson(spSavedCookies)
        : SimpleCookieJar();
    final client = _spClient(jar);

    List<AttendanceInput> spRecords = const [];
    if (spSavedCookies != null) {
      try {
        spRecords = await client.fetchAttendance();
      } catch (_) {
        spRecords = const [];
      }
    }

    if (spRecords.isEmpty) {
      if (!hasPassword) {
        // A saved session that stopped working, and no password to renew it.
        throw const SpSyncException('Your Student Portal session expired. '
            'Add your Student Portal password to keep attendance updating.');
      }
      final netId = email.split('@').first;
      onProgress?.call(SyncStep.solvingCaptcha);
      var result = await client.login(netId, spPassword);
      for (int attempt = 0;
          attempt < 3 && result is SPCaptchaRequired && onSpCaptcha != null;
          attempt++) {
        final pending = result;
        final typed = await onSpCaptcha(pending.captchaImage);
        if (typed == null || typed.trim().isEmpty) {
          throw const SpSyncException('Student Portal sign-in was cancelled.');
        }
        onProgress?.call(SyncStep.studentPortal);
        result = await client.submitLogin(
            pending.context, netId, spPassword, typed.trim());
      }
      switch (result) {
        case SPLoginSuccess():
          break;
        case SPLoginFailure(:final message):
          throw SpSyncException(message.isEmpty
              ? 'Student Portal rejected your password.'
              : 'Student Portal: $message');
        case SPCaptchaRequired():
          throw const SpSyncException(
              "Couldn't solve the Student Portal CAPTCHA. Try again.");
      }
      onProgress?.call(SyncStep.studentPortal);
      spRecords = await client.fetchAttendance();
    }

    await _vault.saveSpCookies(jar.toJson());

    // The attendance is returned (and saved) without waiting for the marks
    // page; the marks follow in the background.
    _spMarks = _syncSpMarks(email, client);
    return spRecords;
  }

  /// The Student Portal marks download started by the latest portal sync.
  Future<void> _spMarks = Future.value();

  /// Completes when the latest Student Portal marks download has finished
  /// (it never throws). Background syncs wait for it before closing the
  /// database.
  Future<void> get spMarksDone => _spMarks;

  /// Stores the Student Portal internal marks as a synthetic "Total
  /// (Internal)" test (Bug Fix #6). Optional: a failure is logged and the
  /// cached marks are kept.
  Future<void> _syncSpMarks(String email, SPClient client) async {
    final sw = Stopwatch()..start();
    try {
      final spMarks = await client.fetchInternalMarks(prime: false);
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
      _log('student portal marks ok in ${sw.elapsedMilliseconds} ms');
      await _recordOutcome(email, SyncSection.studentPortalMarks);
    } catch (e) {
      _log('student portal marks skipped after ${sw.elapsedMilliseconds} '
          'ms: ${e.runtimeType}');
      await _recordOutcome(email, SyncSection.studentPortalMarks,
          error: _sectionError(e));
    }
  }

  /// Layer 4: the Student Portal's attendance [spRecords] (the only source
  /// of hours) with each course's title, category, faculty, slot and room
  /// from Academia's [details], keyed by upper-case course code.
  static List<AttendanceInput> withCourseDetails(
    List<AttendanceInput> spRecords,
    Map<String, AttendanceInput> details,
  ) {
    return [
      for (final sp in spRecords)
        if (details[sp.courseCode.trim().toUpperCase()] case final d?)
          AttendanceInput(
            courseCode: sp.courseCode,
            courseTitle:
                d.courseTitle.isNotEmpty ? d.courseTitle : sp.courseTitle,
            hoursConducted: sp.hoursConducted,
            hoursAbsent: sp.hoursAbsent,
            attendancePct: sp.attendancePct,
            category: d.category,
            facultyName: d.facultyName,
            slot: d.slot,
            roomNo: d.roomNo,
          )
        else
          sp,
    ];
  }
}
