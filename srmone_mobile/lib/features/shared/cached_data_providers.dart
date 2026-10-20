// lib/features/shared/cached_data_providers.dart
// App-wide cached views of the local database for the signed-in student.
//
// Each provider opens its Drift query once and keeps the latest value, so
// switching tabs shows data on the first frame instead of re-running the
// query (and briefly rendering an empty state) on every rebuild. JSON
// columns are decoded once per database change, not once per build.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../domain/services/calendar_day_resolver.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import '../../domain/services/timetable_schedule.dart';
import '../../main.dart';
import '../auth/auth_controller.dart';

/// The signed-in student's Academia email, or '' when signed out.
final currentEmailProvider = Provider<String>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is Authenticated ? auth.email : '';
});

/// Watches [query] for the signed-in student; emits [empty] when signed out.
Stream<T> _forUser<T>(
    Ref ref, Stream<T> Function(AppDatabase db, String email) query, T empty) {
  final email = ref.watch(currentEmailProvider);
  if (email.isEmpty) return Stream.value(empty);
  return query(ref.watch(appDatabaseProvider), email);
}

final studentProfileProvider = StreamProvider<StudentProfile?>(
    (ref) => _forUser(ref, (db, e) => db.watchStudentProfile(e), null));

final attendanceRecordsProvider = StreamProvider<List<AttendanceCacheData>>(
    (ref) => _forUser(ref, (db, e) => db.watchAttendanceRecords(e), const []));

final attendanceSnapshotsProvider = StreamProvider<List<AttendanceSnapshot>>(
    (ref) =>
        _forUser(ref, (db, e) => db.watchAttendanceSnapshots(e), const []));

final marksProvider = StreamProvider<List<MarksCacheData>>(
    (ref) => _forUser(ref, (db, e) => db.watchMarks(e), const []));

final timetableProvider = StreamProvider<TimetableCacheData?>(
    (ref) => _forUser(ref, (db, e) => db.watchTimetable(e), null));

final userSettingsProvider = StreamProvider<UserSettingsTableData?>(
    (ref) => _forUser(ref, (db, e) => db.watchUserSettings(e), null));

/// How each [SyncSection] last went, keyed by section, for showing which
/// data is stale and why. Sections never attempted are missing.
final syncStatusProvider =
    StreamProvider<Map<SyncSection, SyncSectionStatusData>>((ref) {
  return _forUser(ref, (db, e) => db.watchSyncStatus(e), const [])
      .map((rows) => {
            for (final r in rows)
              for (final s in SyncSection.values)
                if (s.name == r.section) s: r,
          });
});

/// The cached calendar row for a semester ('odd' | 'even').
final calendarProvider = StreamProvider.family<CalendarCacheData?, String>(
    (ref, sem) => _forUser(ref, (db, e) => db.watchCalendar(e, sem), null));

/// The timetable courses, decoded.
final timetableCoursesProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final json = ref.watch(timetableProvider).valueOrNull?.coursesJson;
  return TimetableSchedule.parseCourses(json);
});

/// A semester's calendar as a date-key → entry map.
final calendarMapProvider =
    Provider.family<Map<String, CalendarEntry>, String>((ref, sem) {
  final json = ref.watch(calendarProvider(sem)).valueOrNull?.monthsJson;
  return TimetableSchedule.parseCalendar(json);
});

/// A semester's calendar as the stored list of months.
final calendarMonthsProvider =
    Provider.family<List<Map<String, dynamic>>, String>((ref, sem) {
  final json = ref.watch(calendarProvider(sem)).valueOrNull?.monthsJson;
  if (json == null || json.isEmpty) return const [];
  try {
    return (jsonDecode(json) as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    return const [];
  }
});

/// The semester whose calendar applies today.
String currentSemester() => semesterFor(DateTime.now());
