// test/domain/sync_resilience_test.dart
// Attendance (Student Portal only) keeps refreshing when Academia fails, a
// first sign-in still fails on an Academia error, and each section's outcome
// is recorded for the screens. Portals are faked; HTML is synthetic.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';
import 'package:srmone_mobile/core/network/simple_cookie_jar.dart';
import 'package:srmone_mobile/core/security/secure_vault_service.dart';
import 'package:srmone_mobile/domain/services/attendance_planner_math.dart';
import 'package:srmone_mobile/domain/services/notification_rule_engine.dart';
import 'package:srmone_mobile/domain/services/session_sync_orchestrator.dart';
import 'package:srmone_mobile/scrapers/student_portal/sp_client.dart';
import 'package:srmone_mobile/scrapers/student_portal/sp_parsers.dart';

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
</body></html>
''';

class _Vault extends SecureVaultService {
  /// Whether a Student Portal session is saved.
  bool spCookies = true;

  @override
  Future<String?> getAcademiaEmail() async => _email;
  @override
  Future<String?> getAcademiaPassword() async => 'fake-placeholder';
  @override
  Future<String?> getAcademiaCookiesJson() async =>
      (SimpleCookieJar()..set('academia.srmist.edu.in', 'JSESSIONID', 'sess-1'))
          .toJson();
  @override
  Future<void> saveAcademiaCookies(String cookiesJson) async {}
  @override
  Future<String?> getSpPassword() async => null;
  @override
  Future<String?> getSpCookiesJson() async =>
      spCookies ? SimpleCookieJar().toJson() : null;
  @override
  Future<void> saveSpCookies(String cookiesJson) async {}
}

/// Academia: serves the course page, or fails every request when [down].
class _FakeAcademia implements HttpClientAdapter {
  bool down = false;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests++;
    if (down) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'unreachable');
    }
    final body = options.uri.pathSegments.last == 'My_Time_Table_2023_24'
        ? _timetablePage
        : '';
    return ResponseBody.fromBytes(utf8.encode(body), 200, headers: {
      'content-type': ['text/html'],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// A Student Portal with a working saved session, unless it [fails].
class _FakePortal extends SPClient {
  final bool fails;
  int attendanceFetches = 0;

  _FakePortal(SimpleCookieJar jar, {this.fails = false})
      : super(cookieJar: jar);

  @override
  Future<List<AttendanceInput>> fetchAttendance() async {
    attendanceFetches++;
    if (fails) throw Exception('portal down');
    return const [
      AttendanceInput(
        courseCode: '21CSC101T',
        courseTitle: 'ALGORITHMS',
        hoursConducted: 30,
        hoursAbsent: 3,
        attendancePct: 90,
      ),
    ];
  }

  @override
  Future<SPLoginResult> login(String netId, String password) async =>
      const SPLoginFailure('not expected in these tests');

  @override
  Future<List<SPMarkRecord>> fetchInternalMarks({bool prime = true}) async =>
      const [];
}

void main() {
  late AppDatabase db;
  late _FakeAcademia academia;
  late _Vault vault;
  late _FakePortal portal;
  var portalFails = false;

  SessionSyncOrchestrator orchestrator() => SessionSyncOrchestrator(
        db: db,
        vault: vault,
        notifEngine: NotificationRuleEngine(
          db: db,
          notifPlugin: FlutterLocalNotificationsPlugin(),
        ),
        academiaDio: Dio()..httpClientAdapter = academia,
        spClient: (jar) => portal = _FakePortal(jar, fails: portalFails),
      );

  Future<Map<String, SyncSectionStatusData>> statuses() async => {
        for (final r in await db.watchSyncStatus(_email).first) r.section: r,
      };

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    academia = _FakeAcademia();
    vault = _Vault();
    portalFails = false;
  });

  tearDown(() => db.close());

  test('attendance still refreshes when Academia is down', () async {
    academia.down = true;
    final result = await orchestrator().syncAll();

    expect(result.status, SyncStatus.partial);
    expect(result.subjectsUpdated, 1);
    expect(result.errorMessage, contains("Couldn't reach SRM Academia"));
    final saved = await db.watchAttendanceRecords(_email).first;
    expect(saved.single.hoursConducted, 30);

    final s = await statuses();
    expect(s['academia']!.lastError, isNotNull);
    expect(s['academia']!.lastSuccessAt, isNull);
    expect(s['attendance']!.lastError, isNull);
    expect(s['attendance']!.lastSuccessAt, isNotNull);
  });

  test('both portals failing is an error, and cached attendance stays',
      () async {
    academia.down = true;
    portalFails = true;
    await db.replaceAttendanceRecords(_email, [
      const AttendanceCacheCompanion(
        academiaEmail: Value(_email),
        courseCode: Value('21CSC101T'),
        hoursConducted: Value(20),
      ),
    ]);

    final result = await orchestrator().syncAll();

    expect(result.status, SyncStatus.error);
    expect(
        (await db.watchAttendanceRecords(_email).first).single.hoursConducted,
        20);
    expect((await statuses())['attendance']!.lastError, isNotNull);
  });

  test('a first sign-in fails on an Academia error without the portal',
      () async {
    academia.down = true;
    final result = await orchestrator().syncAll(forceFreshLogin: true);

    expect(result.status, SyncStatus.error);
    expect(await db.watchAttendanceRecords(_email).first, isEmpty);
  });

  test('a refresh without the portal step reports the Academia error',
      () async {
    academia.down = true;
    final result = await orchestrator().syncAll(includeStudentPortal: false);

    expect(result.status, SyncStatus.error);
    expect((await statuses())['academia']!.lastError, isNotNull);
  });

  test('a good sync records every section as fresh', () async {
    final result = await orchestrator().syncAll();

    expect(result.status, SyncStatus.success);
    expect(portal.attendanceFetches, 1);
    final s = await statuses();
    for (final section in ['academia', 'profile', 'marks', 'attendance']) {
      expect(s[section]?.lastError, isNull, reason: section);
      expect(s[section]?.lastSuccessAt, isNotNull, reason: section);
    }
  });

  test('a later failure keeps the last success time', () async {
    await orchestrator().syncAll();
    final firstSuccess = (await statuses())['academia']!.lastSuccessAt;

    academia.down = true;
    await orchestrator().syncAll();

    final academiaStatus = (await statuses())['academia']!;
    expect(academiaStatus.lastSuccessAt, firstSuccess);
    expect(academiaStatus.lastError, isNotNull);
  });

  test('an expired portal session with no password is not connected', () async {
    portalFails = true;
    vault.spCookies = true;
    final result = await orchestrator().connectStudentPortal(required: false);

    // A saved session that no longer works and no password to sign in with.
    expect(result.connected, isFalse);
    expect(result.message, contains('session expired'));
    expect((await statuses())['attendance']!.lastError,
        contains('session expired'));
    expect(await db.watchAttendanceRecords(_email).first, isEmpty);
  });
}
