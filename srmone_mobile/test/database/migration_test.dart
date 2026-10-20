// test/database/migration_test.dart
// Every saved schema version must upgrade to the current one without losing
// data. After a schema change: bump schemaVersion, add the onUpgrade step,
// then run
//   dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
//   dart run drift_dev schema generate drift_schemas/ test/database/generated/

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every older schema upgrades to the current one', () async {
    for (var from = 1; from < AppDatabase.currentSchemaVersion; from++) {
      final schema = await verifier.schemaAt(from);
      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, AppDatabase.currentSchemaVersion);
      await db.close();
    }
  });

  test('v1 to v2 keeps cached attendance and adds sync status', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old.customStatement(
        'INSERT INTO attendance_cache (academia_email, course_code, '
        'hours_conducted, hours_absent, attendance_pct, source) VALUES '
        "('ab1234@srmist.edu.in', '21CSC101T', 20, 2, 90.0, 'student_portal')");
    await old.close();

    final db = AppDatabase.forTesting(schema.newConnection());
    await verifier.migrateAndValidate(db, 2);
    final rows = await db.watchAttendanceRecords('ab1234@srmist.edu.in').first;
    expect(rows.single.hoursConducted, 20);

    await db.recordSyncOutcome('ab1234@srmist.edu.in', 'attendance');
    final status = await db.watchSyncStatus('ab1234@srmist.edu.in').first;
    expect(status.single.lastError, isNull);
    await db.close();
  });
}
