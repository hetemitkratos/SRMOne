// test/domain/sync_storage_test.dart
// Replace-style writes drop rows that disappeared from the portal.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';

AttendanceCacheCompanion _row(String code, {String category = ''}) =>
    AttendanceCacheCompanion(
      academiaEmail: const drift.Value('a@srmist.edu.in'),
      courseCode: drift.Value(code),
      category: drift.Value(category),
      hoursConducted: const drift.Value(10),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('replaceAttendanceRecords removes stale courses', () async {
    await db.replaceAttendanceRecords(
        'a@srmist.edu.in', [_row('OLD101'), _row('KEEP101')]);
    await db.replaceAttendanceRecords(
        'a@srmist.edu.in', [_row('KEEP101', category: 'Professional Core')]);

    final rows = await db.watchAttendanceRecords('a@srmist.edu.in').first;
    expect(rows.map((r) => '${r.courseCode}/${r.category}'),
        ['KEEP101/Professional Core']);
  });

  test('replaceMarksRecords only touches the given source', () async {
    MarksCacheCompanion mark(String code, String source) => MarksCacheCompanion(
          academiaEmail: const drift.Value('a@srmist.edu.in'),
          courseCode: drift.Value(code),
          source: drift.Value(source),
        );
    await db.replaceMarksRecords(
        'a@srmist.edu.in', 'academia', [mark('X1', 'academia')]);
    await db.replaceMarksRecords(
        'a@srmist.edu.in', 'student_portal', [mark('X1', 'student_portal')]);
    await db.replaceMarksRecords(
        'a@srmist.edu.in', 'academia', [mark('Y2', 'academia')]);

    final rows = await db.getMarks('a@srmist.edu.in');
    expect(rows.map((r) => '${r.courseCode}/${r.source}').toSet(),
        {'Y2/academia', 'X1/student_portal'});
  });
}
