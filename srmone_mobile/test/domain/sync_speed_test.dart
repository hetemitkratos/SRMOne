// test/domain/sync_speed_test.dart
// The sync saves the My_Time_Table data before the slower timetable and
// calendar pages arrive, shares one run between concurrent callers, and
// downloads the shared Academic_Reports page once. HTML is synthetic.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';
import 'package:srmone_mobile/core/network/simple_cookie_jar.dart';
import 'package:srmone_mobile/core/security/secure_vault_service.dart';
import 'package:srmone_mobile/domain/services/attendance_planner_math.dart';
import 'package:srmone_mobile/domain/services/notification_rule_engine.dart';
import 'package:srmone_mobile/domain/services/session_sync_orchestrator.dart';

const _email = 'ab1234@srmist.edu.in';

const _timetablePage = '''
<html><body>
<table>
  <tr><td>Registration Number:</td><td>RA0000000000001</td><td>Name:</td><td>Test Student</td></tr>
  <tr><td>Batch:</td><td>2</td><td>Program:</td><td>B.Tech</td></tr>
</table>
<table>
  <tr><th>S.No</th><th>Course Code</th><th>Course Title</th><th>Credit</th>
      <th>Category</th><th>Course Type</th><th>Faculty Name</th><th>Slot</th><th>Room No.</th></tr>
  <tr><td>1</td><td>21CSC101T</td><td>Algorithms</td><td>3</td><td>Professional Core</td>
      <td>Theory</td><td>Dr. A B (100001)</td><td>A-</td><td>LH101</td></tr>
</table>
<table>
  <tr><th>Course Code</th><th>Course Title</th><th>Category</th><th>Faculty Name</th>
      <th>Slot</th><th>Room No</th><th>Hours Conducted</th><th>Hours Absent</th><th>Attn %</th></tr>
  <tr><td>21CSC101T<br>Regular</td><td>Algorithms</td><td>Professional Core</td>
      <td>Dr. A B (100001)</td><td>A</td><td>LH101</td><td>20</td><td>2</td><td>90.00</td></tr>
</table>
</body></html>
''';

const _unifiedPage = '''
<table>
  <tr><td>FROM</td><td>08:00 - 08:50</td><td>08:50 - 09:40</td></tr>
  <tr><td>TO</td><td></td><td></td></tr>
  <tr><td>Day 1</td><td>A</td><td>B</td></tr>
</table>
''';

const _calendarPage = '''
<table>
  <tr><th>Dt</th><th>Day</th><th>Jul '26</th><th>DO</th></tr>
  <tr><td>1</td><td>Wed</td><td></td><td>1</td></tr>
  <tr><td>2</td><td>Thu</td><td>Holiday - Test</td><td>-</td></tr>
</table>
''';

class _MemoryVault extends SecureVaultService {
  final Map<String, String> values = {
    'email': _email,
    'password': 'secret-pw',
    'cookies': (SimpleCookieJar()
          ..set('academia.srmist.edu.in', 'JSESSIONID', 'sess-1'))
        .toJson(),
  };

  @override
  Future<String?> getAcademiaEmail() async => values['email'];
  @override
  Future<String?> getAcademiaPassword() async => values['password'];
  @override
  Future<String?> getAcademiaCookiesJson() async => values['cookies'];
  @override
  Future<void> saveAcademiaCookies(String cookiesJson) async =>
      values['cookies'] = cookiesJson;

  /// Whether the Student Portal counts as set up.
  bool spConfigured = false;

  @override
  Future<String?> getSpPassword() async => spConfigured ? 'x' : null;
  @override
  Future<String?> getSpCookiesJson() async => null;
}

/// Serves the pages above; the unified timetable waits for [releaseGrid].
class _FakeAcademia implements HttpClientAdapter {
  final requests = <String>[];
  final releaseGrid = Completer<void>();

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final page = options.uri.pathSegments.last;
    requests.add(page);
    String body;
    switch (page) {
      case 'My_Time_Table_2023_24':
        body = _timetablePage;
      case 'Unified_Time_Table_2025_batch_2':
        await releaseGrid.future;
        body = _unifiedPage;
      case 'Academic_Reports':
        body = _calendarPage;
      default:
        return ResponseBody.fromString('', 404);
    }
    return ResponseBody.fromBytes(utf8.encode(body), 200, headers: {
      'content-type': ['text/html'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late _FakeAcademia academia;
  late _MemoryVault vault;
  late SessionSyncOrchestrator orchestrator;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    academia = _FakeAcademia();
    vault = _MemoryVault();
    orchestrator = SessionSyncOrchestrator(
      db: db,
      vault: vault,
      notifEngine: NotificationRuleEngine(
        db: db,
        notifPlugin: FlutterLocalNotificationsPlugin(),
      ),
      academiaDio: Dio()..httpClientAdapter = academia,
    );
  });

  tearDown(() => db.close());

  test('saves the profile before the timetable grid arrives', () async {
    final result = await orchestrator.syncAll(
        includeStudentPortal: false, waitForDetails: false);

    expect(result.status, SyncStatus.success);
    // Attendance comes only from the Student Portal, even when the Academia
    // page has an attendance table.
    expect(await db.watchAttendanceRecords(_email).first, isEmpty);
    expect((await db.getStudentProfile(_email))?.name, 'Test Student');
    expect(await db.getTimetable(_email), isNull);
    expect(orchestrator.isSyncing, isTrue);

    academia.releaseGrid.complete();
    // A caller that waits for details joins the run instead of starting one.
    await orchestrator.syncAll(includeStudentPortal: false);

    expect(await db.getTimetable(_email), isNotNull);
    expect(orchestrator.isSyncing, isFalse);
    expect(academia.requests.where((p) => p == 'My_Time_Table_2023_24'),
        hasLength(1));
  });

  test('both semesters share one Academic_Reports download', () async {
    academia.releaseGrid.complete();
    await orchestrator.syncAll(includeStudentPortal: false);

    expect(
        academia.requests.where((p) => p == 'Academic_Reports'), hasLength(1));
    expect(await db.getCalendar(_email, 'odd'), isNotNull);
    expect(await db.getCalendar(_email, 'even'), isNotNull);
  });

  test('concurrent refreshes run one sync', () async {
    academia.releaseGrid.complete();
    final results = await Future.wait([
      orchestrator.syncAll(includeStudentPortal: false),
      orchestrator.syncAll(includeStudentPortal: false),
    ]);

    expect(results.map((r) => r.status), everyElement(SyncStatus.success));
    expect(academia.requests.where((p) => p == 'My_Time_Table_2023_24'),
        hasLength(1));
  });

  test('lastSyncedAt reflects the last Academia sync', () async {
    expect(await orchestrator.lastSyncedAt(_email), isNull);
    academia.releaseGrid.complete();
    await orchestrator.syncAll(includeStudentPortal: false);
    final last = await orchestrator.lastSyncedAt(_email);
    expect(DateTime.now().difference(last!).inMinutes, lessThan(1));
  });

  test('a second sync reuses the cached grid and calendar unless forced',
      () async {
    academia.releaseGrid.complete();
    await orchestrator.syncAll(includeStudentPortal: false);
    academia.requests.clear();

    await orchestrator.syncAll(includeStudentPortal: false);
    expect(academia.requests, ['My_Time_Table_2023_24']);

    academia.requests.clear();
    await orchestrator.syncAll(includeStudentPortal: false, forceDetails: true);
    expect(academia.requests, contains('Unified_Time_Table_2025_batch_2'));
    expect(academia.requests, contains('Academic_Reports'));
  });

  test('a missing other-semester calendar does not force a download', () async {
    await db.upsertCalendar(CalendarCacheCompanion(
      academiaEmail: const drift.Value(_email),
      semester: drift.Value(semesterFor(DateTime.now())),
      monthsJson: const drift.Value('[]'),
      updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
    ));
    academia.releaseGrid.complete();
    await orchestrator.syncAll(includeStudentPortal: false);

    expect(academia.requests, isNot(contains('Academic_Reports')));
  });

  test('an Academia sync leaves the Student Portal attendance alone', () async {
    vault.spConfigured = true;
    await db.replaceAttendanceRecords(_email, [
      AttendanceCacheCompanion(
        academiaEmail: const drift.Value(_email),
        courseCode: const drift.Value('21CSC101T'),
        courseTitle: const drift.Value('Algorithms'),
        hoursConducted: const drift.Value(24),
        hoursAbsent: const drift.Value(3),
        attendancePct: const drift.Value(87.5),
        updatedAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
      ),
    ]);
    academia.releaseGrid.complete();
    await orchestrator.syncAll(includeStudentPortal: false);

    final saved = await db.watchAttendanceRecords(_email).first;
    expect(saved.single.hoursConducted, 24);
    expect(saved.single.hoursAbsent, 3);
  });

  test('withCourseDetails adds Academia course details to portal hours', () {
    final merged = SessionSyncOrchestrator.withCourseDetails([
      const AttendanceInput(
        courseCode: '21csc101t',
        courseTitle: 'ALGORITHMS',
        hoursConducted: 24,
        hoursAbsent: 3,
        attendancePct: 87.5,
      ),
      const AttendanceInput(
        courseCode: '21MAB201T',
        courseTitle: 'Transforms',
        hoursConducted: 10,
        hoursAbsent: 0,
        attendancePct: 100,
      ),
    ], {
      '21CSC101T': const AttendanceInput(
        courseCode: '21CSC101T',
        courseTitle: 'Algorithms',
        hoursConducted: 0,
        hoursAbsent: 0,
        attendancePct: 0,
        category: 'Professional Core',
        facultyName: 'Dr. A B (100001)',
        slot: 'A',
        roomNo: 'LH101',
      ),
    });

    expect(merged, hasLength(2));
    final first = merged.first;
    expect(first.courseTitle, 'Algorithms');
    expect((first.hoursConducted, first.hoursAbsent, first.attendancePct),
        (24, 3, 87.5));
    expect((first.facultyName, first.slot, first.roomNo, first.category),
        ('Dr. A B (100001)', 'A', 'LH101', 'Professional Core'));
    // A course Academia doesn't list keeps the portal's own fields.
    expect(merged.last.courseTitle, 'Transforms');
    expect(merged.last.hoursConducted, 10);
  });
}
