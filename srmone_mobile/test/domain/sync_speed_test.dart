// test/domain/sync_speed_test.dart
// The sync saves the My_Time_Table data before the slower timetable and
// calendar pages arrive, shares one run between concurrent callers, and
// downloads the shared Academic_Reports page once. HTML is synthetic.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';
import 'package:srmone_mobile/core/network/simple_cookie_jar.dart';
import 'package:srmone_mobile/core/security/secure_vault_service.dart';
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
  @override
  Future<String?> getSpPassword() async => null;
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
  late SessionSyncOrchestrator orchestrator;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    academia = _FakeAcademia();
    orchestrator = SessionSyncOrchestrator(
      db: db,
      vault: _MemoryVault(),
      notifEngine: NotificationRuleEngine(
        db: db,
        notifPlugin: FlutterLocalNotificationsPlugin(),
      ),
      academiaDio: Dio()..httpClientAdapter = academia,
    );
  });

  tearDown(() => db.close());

  test('saves attendance and profile before the timetable grid arrives',
      () async {
    final result = await orchestrator.syncAll(
        includeStudentPortal: false, waitForDetails: false);

    expect(result.status, SyncStatus.success);
    expect(await db.watchAttendanceRecords(_email).first, hasLength(1));
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

  test('lastSyncedAt reflects the saved attendance', () async {
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
}
