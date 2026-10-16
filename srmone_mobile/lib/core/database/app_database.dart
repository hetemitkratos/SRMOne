// lib/core/database/app_database.dart
// Local SQLite database using Drift (formerly Moor).
// Replaces all 11 Supabase PostgreSQL tables with 10 local SQLite tables.
//
// Run code generation after changes:
//   dart run build_runner build --delete-conflicting-outputs

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ─── Table Definitions ────────────────────────────────────────────────────────

/// Replaces public.student_profiles (Supabase)
class StudentProfiles extends Table {
  TextColumn get academiaEmail => text()();
  TextColumn get name => text()();
  TextColumn get regNumber => text().withDefault(const Constant(''))();
  TextColumn get photoUrl => text().withDefault(const Constant(''))();
  RealColumn get cgpa => real().withDefault(const Constant(0.0))();
  TextColumn get branch => text().withDefault(const Constant(''))();
  TextColumn get section => text().withDefault(const Constant(''))();
  TextColumn get semester => text().withDefault(const Constant(''))();
  TextColumn get batch => text().withDefault(const Constant(''))();
  TextColumn get phone => text().withDefault(const Constant(''))();
  TextColumn get email => text().withDefault(const Constant(''))();
  TextColumn get parentEmail => text().withDefault(const Constant(''))();
  TextColumn get parentPhone => text().withDefault(const Constant(''))();
  TextColumn get mentor => text().withDefault(const Constant(''))();
  TextColumn get program => text().withDefault(const Constant(''))();
  TextColumn get campus => text().withDefault(const Constant(''))();
  TextColumn get rawDataJson => text().withDefault(const Constant('{}'))();
  IntColumn get cachedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {academiaEmail};
}

/// Replaces in-memory sessions[email].cache.attendance (server.js)
class AttendanceCache extends Table {
  TextColumn get academiaEmail => text()();
  TextColumn get courseCode => text()();
  TextColumn get courseTitle => text().withDefault(const Constant(''))();
  TextColumn get category => text().withDefault(const Constant(''))();
  TextColumn get facultyName => text().withDefault(const Constant(''))();
  TextColumn get slot => text().withDefault(const Constant(''))();
  TextColumn get roomNo => text().withDefault(const Constant(''))();
  IntColumn get hoursConducted => integer().withDefault(const Constant(0))();
  IntColumn get hoursAbsent => integer().withDefault(const Constant(0))();
  RealColumn get attendancePct => real().withDefault(const Constant(0.0))();
  TextColumn get source => text().withDefault(const Constant('academia'))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {academiaEmail, courseCode, category};
}

/// Replaces public.attendance_snapshots (Supabase)
class AttendanceSnapshots extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get academiaEmail => text()();
  TextColumn get snapshotDate => text()(); // YYYY-MM-DD
  RealColumn get overallPercentage =>
      real().withDefault(const Constant(0.0))(); // unweighted mean
  RealColumn get weightedPercentage =>
      real().withDefault(const Constant(0.0))();
  TextColumn get subjectsJson => text().withDefault(const Constant('[]'))();
  IntColumn get totalClasses => integer().withDefault(const Constant(0))();
  IntColumn get attendedClasses => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {academiaEmail, snapshotDate},
      ];
}

/// Replaces timetable_cache (Supabase)
class TimetableCache extends Table {
  TextColumn get academiaEmail => text()();
  TextColumn get batch => text().withDefault(const Constant(''))();
  TextColumn get coursesJson => text().withDefault(const Constant('[]'))();
  TextColumn get advisorsJson => text().withDefault(const Constant('[]'))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {academiaEmail};
}

/// Replaces marks_cache (Supabase)
class MarksCache extends Table {
  TextColumn get academiaEmail => text()();
  TextColumn get courseCode => text()();
  TextColumn get courseTitle => text().withDefault(const Constant(''))();
  TextColumn get courseType => text().withDefault(const Constant(''))();
  TextColumn get source => text().withDefault(const Constant('academia'))();
  TextColumn get testsJson => text().withDefault(const Constant('[]'))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {academiaEmail, courseCode, source};
}

/// Replaces calendar_cache (Supabase)
class CalendarCache extends Table {
  TextColumn get academiaEmail => text()();
  TextColumn get semester => text()(); // 'odd' | 'even'
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get monthsJson => text().withDefault(const Constant('[]'))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {academiaEmail, semester};
}

/// Replaces faculty_cache (Supabase)
class FacultyCache extends Table {
  TextColumn get slug => text()();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get photoUrl => text().withDefault(const Constant(''))();
  TextColumn get designation => text().withDefault(const Constant(''))();
  TextColumn get department => text().withDefault(const Constant(''))();
  TextColumn get emailAddress => text().withDefault(const Constant(''))();
  TextColumn get campus => text().withDefault(const Constant(''))();
  TextColumn get experience => text().withDefault(const Constant(''))();
  TextColumn get researchInterest => text().withDefault(const Constant(''))();
  TextColumn get courses => text().withDefault(const Constant(''))();
  TextColumn get education => text().withDefault(const Constant(''))();
  TextColumn get publications => text().withDefault(const Constant(''))();
  TextColumn get awards => text().withDefault(const Constant(''))();
  TextColumn get workshops => text().withDefault(const Constant(''))();
  TextColumn get workExperience => text().withDefault(const Constant(''))();
  TextColumn get memberships => text().withDefault(const Constant(''))();
  TextColumn get responsibilities => text().withDefault(const Constant(''))();
  TextColumn get profileUrl => text().withDefault(const Constant(''))();
  IntColumn get cachedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {slug};
}

/// Replaces public.user_settings (Supabase)
class UserSettingsTable extends Table {
  TextColumn get academiaEmail => text()();
  TextColumn get theme => text().withDefault(const Constant('light'))();
  TextColumn get defaultView =>
      text().withDefault(const Constant('overview'))();
  RealColumn get attendanceThreshold =>
      real().withDefault(const Constant(75.0))();
  TextColumn get calendarView => text().withDefault(const Constant('month'))();
  TextColumn get timetableView => text().withDefault(const Constant('week'))();
  IntColumn get showWeekends => integer().withDefault(const Constant(1))();
  IntColumn get biometricLockEnabled =>
      integer().withDefault(const Constant(0))();
  TextColumn get customSpRelayUrl => text().nullable()();
  TextColumn get dashboardWidgetsJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get customDataJson => text().withDefault(const Constant('{}'))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {academiaEmail};
}

/// Replaces public.notification_settings (Supabase)
class NotificationSettingsTable extends Table {
  TextColumn get academiaEmail => text()();
  IntColumn get attendanceAlertEnabled =>
      integer().withDefault(const Constant(1))();
  RealColumn get attendanceThreshold =>
      real().withDefault(const Constant(75.0))();
  IntColumn get holidayAlertsEnabled =>
      integer().withDefault(const Constant(1))();
  IntColumn get pushEnabled => integer().withDefault(const Constant(1))();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {academiaEmail};
}

/// Replaces public.notifications (Supabase Realtime → reactive Drift stream)
class NotificationsTable extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get academiaEmail => text()();
  TextColumn get type =>
      text()(); // 'low_attendance'|'welcome'|'holiday_alert'|'test'
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get dataJson => text().withDefault(const Constant('{}'))();
  IntColumn get read => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Database Class ───────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    StudentProfiles,
    AttendanceCache,
    AttendanceSnapshots,
    TimetableCache,
    MarksCache,
    CalendarCache,
    FacultyCache,
    UserSettingsTable,
    NotificationSettingsTable,
    NotificationsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );

  // ─── Attendance DAO ─────────────────────────────────────────────────────────

  /// Reactive stream of all attendance records for an email.
  /// Screens subscribe to this and render cached data immediately (SWR Layer 1).
  Stream<List<AttendanceCacheData>> watchAttendanceRecords(
      String academiaEmail) {
    return (select(attendanceCache)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .watch();
  }

  Future<void> upsertAttendanceRecords(
      List<AttendanceCacheCompanion> records) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(attendanceCache, records);
    });
  }

  // ─── Notifications DAO ──────────────────────────────────────────────────────

  /// Reactive stream of unread notification count.
  /// BUG FIX: replaces the manual increment/decrement in useNotifications.js
  /// which caused negative drift on UPDATE events.
  Stream<int> watchUnreadNotificationCount(String academiaEmail) {
    final query = selectOnly(notificationsTable)
      ..addColumns([notificationsTable.id.count()])
      ..where(notificationsTable.academiaEmail.equals(academiaEmail) &
          notificationsTable.read.equals(0));
    return query
        .map((row) => row.read(notificationsTable.id.count()) ?? 0)
        .watchSingle();
  }

  Stream<List<NotificationsTableData>> watchNotifications(
      String academiaEmail) {
    return (select(notificationsTable)
          ..where((t) => t.academiaEmail.equals(academiaEmail))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .watch();
  }

  Future<void> insertNotification(NotificationsTableCompanion entry) async {
    await into(notificationsTable).insertOnConflictUpdate(entry);
  }

  Future<void> markAllNotificationsRead(String academiaEmail) async {
    await (update(notificationsTable)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .write(const NotificationsTableCompanion(read: Value(1)));
  }

  Future<List<NotificationsTableData>> getRecentNotificationsByType(
    String academiaEmail,
    String type, {
    int limit = 5,
  }) async {
    return (select(notificationsTable)
          ..where(
            (t) => t.academiaEmail.equals(academiaEmail) & t.type.equals(type),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .get();
  }

  // ─── Student Profile DAO ────────────────────────────────────────────────────

  Stream<StudentProfile?> watchStudentProfile(String academiaEmail) {
    return (select(studentProfiles)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .watchSingleOrNull();
  }

  Future<StudentProfile?> getStudentProfile(String academiaEmail) {
    return (select(studentProfiles)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .getSingleOrNull();
  }

  Future<void> upsertStudentProfile(StudentProfilesCompanion entry) async {
    await into(studentProfiles).insertOnConflictUpdate(entry);
  }

  // ─── Timetable DAO ──────────────────────────────────────────────────────────

  Stream<TimetableCacheData?> watchTimetable(String academiaEmail) {
    return (select(timetableCache)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .watchSingleOrNull();
  }

  Future<TimetableCacheData?> getTimetable(String academiaEmail) {
    return (select(timetableCache)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .getSingleOrNull();
  }

  Future<void> upsertTimetable(TimetableCacheCompanion entry) async {
    await into(timetableCache).insertOnConflictUpdate(entry);
  }

  // ─── Calendar DAO ───────────────────────────────────────────────────────────

  Stream<CalendarCacheData?> watchCalendar(
      String academiaEmail, String semester) {
    return (select(calendarCache)
          ..where((t) =>
              t.academiaEmail.equals(academiaEmail) &
              t.semester.equals(semester)))
        .watchSingleOrNull();
  }

  Future<CalendarCacheData?> getCalendar(
      String academiaEmail, String semester) {
    return (select(calendarCache)
          ..where((t) =>
              t.academiaEmail.equals(academiaEmail) &
              t.semester.equals(semester)))
        .getSingleOrNull();
  }

  Future<void> upsertCalendar(CalendarCacheCompanion entry) async {
    await into(calendarCache).insertOnConflictUpdate(entry);
  }

  // ─── Marks DAO ──────────────────────────────────────────────────────────────

  Stream<List<MarksCacheData>> watchMarks(String academiaEmail) {
    return (select(marksCache)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .watch();
  }

  Future<List<MarksCacheData>> getMarks(String academiaEmail) {
    return (select(marksCache)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .get();
  }

  Future<void> upsertMarksRecords(List<MarksCacheCompanion> records) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(marksCache, records);
    });
  }

  // ─── Settings DAO ───────────────────────────────────────────────────────────

  Stream<UserSettingsTableData?> watchUserSettings(String academiaEmail) {
    return (select(userSettingsTable)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .watchSingleOrNull();
  }

  Future<void> upsertUserSettings(UserSettingsTableCompanion entry) async {
    await into(userSettingsTable).insertOnConflictUpdate(entry);
  }

  Stream<NotificationSettingsTableData?> watchNotificationSettings(
      String academiaEmail) {
    return (select(notificationSettingsTable)
          ..where((t) => t.academiaEmail.equals(academiaEmail)))
        .watchSingleOrNull();
  }

  Future<void> upsertNotificationSettings(
      NotificationSettingsTableCompanion entry) async {
    await into(notificationSettingsTable).insertOnConflictUpdate(entry);
  }

  // ─── Attendance Snapshots DAO ───────────────────────────────────────────────

  Future<void> upsertAttendanceSnapshot(
      AttendanceSnapshotsCompanion entry) async {
    // Use insert with conflict resolution on (academiaEmail, snapshotDate)
    await into(attendanceSnapshots).insertOnConflictUpdate(entry);
  }

  Stream<List<AttendanceSnapshot>> watchAttendanceSnapshots(
    String academiaEmail, {
    int limit = 30,
  }) {
    return (select(attendanceSnapshots)
          ..where((t) => t.academiaEmail.equals(academiaEmail))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.snapshotDate, mode: OrderingMode.asc)
          ])
          ..limit(limit))
        .watch();
  }

  Future<List<AttendanceSnapshot>> getAttendanceSnapshots(
    String academiaEmail, {
    int limit = 30,
  }) async {
    return (select(attendanceSnapshots)
          ..where((t) => t.academiaEmail.equals(academiaEmail))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.snapshotDate, mode: OrderingMode.desc)
          ])
          ..limit(limit))
        .get();
  }
}

// ─── Database Connection ──────────────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'srmone.db'));
    return NativeDatabase.createInBackground(file);
  });
}
