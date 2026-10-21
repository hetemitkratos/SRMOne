// lib/domain/services/notification_rule_engine.dart
// On-device notification rule engine.
// Runs automatically after every foreground or WorkManager background sync.
// Specification: plan.md §2.5
//
// Bug Fix #5: unreadCount is derived from reactive SQLite stream, not manually
//             incremented (which caused negative drift in useNotifications.js).

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import 'attendance_planner_math.dart';
import 'calendar_day_resolver.dart';
import 'day_timeline.dart';

const _uuid = Uuid();

const _androidChannel = AndroidNotificationDetails(
  'srmone_alerts',
  'SRMOne Alerts',
  channelDescription: 'Attendance alerts, holidays, and updates',
  importance: Importance.high,
  priority: Priority.high,
);

const _notifDetails = NotificationDetails(android: _androidChannel);

class NotificationRuleEngine {
  final AppDatabase _db;
  final FlutterLocalNotificationsPlugin _notifPlugin;

  NotificationRuleEngine({
    required AppDatabase db,
    required FlutterLocalNotificationsPlugin notifPlugin,
  })  : _db = db,
        _notifPlugin = notifPlugin;

  // ─── Rule 1: Daily Snapshot Upsert ─────────────────────────────────────────

  /// Computes today's attendance metrics and upserts a snapshot row.
  /// Always called before checking notification preferences.
  Future<void> upsertDailySnapshot(
    String academiaEmail,
    List<AttendanceInput> records,
  ) async {
    // Rows with no hours yet (Academia courses before the portal fills
    // them in) would record a meaningless 0% day.
    if (records.every((r) => r.hoursConducted <= 0)) return;

    final summary = computeAttendanceSummary(records);
    final todayKey = CalendarDayResolver.localDateKey(DateTime.now());
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.upsertAttendanceSnapshot(
      AttendanceSnapshotsCompanion(
        academiaEmail: drift.Value(academiaEmail),
        snapshotDate: drift.Value(todayKey),
        overallPercentage: drift.Value(summary.unweightedMeanPct),
        weightedPercentage: drift.Value(summary.weightedOverallPct),
        subjectsJson: drift.Value(jsonEncode(
          records
              .map((r) => {
                    'courseCode': r.courseCode,
                    'attendancePct': r.attendancePct,
                  })
              .toList(),
        )),
        totalClasses:
            drift.Value(records.fold(0, (s, r) => s + r.hoursConducted)),
        attendedClasses:
            drift.Value(records.fold(0, (s, r) => s + r.hoursPresent)),
        createdAt: drift.Value(now),
      ),
    );
  }

  // ─── Rule 2: Low Attendance Alert ──────────────────────────────────────────

  /// Fires a native notification if any subjects are below the configured
  /// attendance threshold, at most once per calendar day.
  Future<void> maybeNotifyLowAttendance(
    String academiaEmail,
    List<AttendanceInput> records, {
    double threshold = 75.0,
    bool alertEnabled = true,
  }) async {
    if (!alertEnabled) return;

    final effectiveThreshold = threshold > 0 ? threshold : 75.0;
    final below = records
        .where(
            (r) => r.hoursConducted > 0 && r.attendancePct < effectiveThreshold)
        .toList()
      ..sort((a, b) => a.attendancePct.compareTo(b.attendancePct));

    if (below.isEmpty) return;

    // Once a day: skip if one was already sent today (cleared ones count).
    final recent = await _db.getRecentNotificationsByType(
      academiaEmail,
      'low_attendance',
      limit: 1,
    );
    if (recent.isNotEmpty &&
        _sameDay(DateTime.fromMillisecondsSinceEpoch(recent.first.createdAt),
            DateTime.now())) {
      return;
    }

    final pct = effectiveThreshold.toStringAsFixed(0);
    final title = 'Attendance below $pct%';
    final String body;
    if (below.length == 1) {
      final r = below.single;
      final needed = computeSubjectCardMetrics(r).needed75;
      body = '${_name(r)} is at ${r.attendancePct.toStringAsFixed(1)}%.'
          '${needed > 0 && effectiveThreshold == 75 ? ' Attend the next $needed class${needed == 1 ? '' : 'es'} to get back to 75%.' : ''}';
    } else {
      body = '${below.length} courses are below $pct%: '
          '${below.map((r) => '${_name(r)} (${r.attendancePct.toStringAsFixed(1)}%)').join(', ')}.';
    }
    final fingerprint = below
        .map((r) => '${r.courseCode}:${r.attendancePct.round()}')
        .join(',');

    await _db.insertNotification(
      NotificationsTableCompanion(
        id: drift.Value(_uuid.v4()),
        academiaEmail: drift.Value(academiaEmail),
        type: const drift.Value('low_attendance'),
        title: drift.Value(title),
        body: drift.Value(body),
        dataJson: drift.Value(jsonEncode({'fingerprint': fingerprint})),
        read: const drift.Value(0),
        createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );

    await _notifPlugin.show(
      'low_attendance'.hashCode,
      title,
      body,
      _notifDetails,
    );
  }

  // ─── Rule 3: Welcome Notification ──────────────────────────────────────────

  /// Fires a welcome notification on first ever successful Academia login.
  Future<void> maybeNotifyWelcome(String academiaEmail) async {
    final existing = await _db.getRecentNotificationsByType(
      academiaEmail,
      'welcome',
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    const title = 'Welcome to SRM One';
    const body = 'Your attendance, marks and timetable are synced. '
        'Pull down on any screen to refresh.';

    await _db.insertNotification(
      NotificationsTableCompanion(
        id: drift.Value(_uuid.v4()),
        academiaEmail: drift.Value(academiaEmail),
        type: const drift.Value('welcome'),
        title: const drift.Value(title),
        body: const drift.Value(body),
        dataJson: const drift.Value('{}'),
        read: const drift.Value(0),
        createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );

    await _notifPlugin.show(
      'welcome'.hashCode,
      title,
      body,
      _notifDetails,
    );
  }

  // ─── Rule 4: Holiday Alert ──────────────────────────────────────────────────

  /// Scans today through today+7 for upcoming holidays and notifies once per
  /// holiday date.
  Future<void> maybeNotifyHoliday(
    String academiaEmail,
    Map<String, CalendarEntry> calendarMap, {
    bool holidayAlertsEnabled = true,
  }) async {
    if (!holidayAlertsEnabled) return;

    final today = DateTime.now();
    String? upcomingHolidayName;
    DateTime? upcomingDate;

    for (int i = 0; i <= 7; i++) {
      final d = today.add(Duration(days: i));
      final status = CalendarDayResolver.getDayStatus(calendarMap, d);
      if (status.isHoliday && status.event.isNotEmpty) {
        upcomingHolidayName = status.event;
        upcomingDate = d;
        break;
      }
    }

    if (upcomingHolidayName == null) return;

    // Once per holiday date, even after the alert was read or cleared.
    final dateStr = CalendarDayResolver.localDateKey(upcomingDate!);
    final existing = await _db.getRecentNotificationsByType(
      academiaEmail,
      'holiday_alert',
      limit: 10,
    );
    final alreadySent = existing.any((n) {
      try {
        return (jsonDecode(n.dataJson) as Map<String, dynamic>)['date'] ==
            dateStr;
      } catch (_) {
        return false;
      }
    });
    if (alreadySent) return;

    final name = upcomingHolidayName
        .replaceAll(RegExp(r'\s*-\s*holiday\s*$', caseSensitive: false), '')
        .trim();
    final title = _sameDay(upcomingDate, today)
        ? 'Holiday today'
        : 'Holiday on ${_weekdays[upcomingDate.weekday - 1]}, '
            '${upcomingDate.day} ${_months[upcomingDate.month - 1]}';
    final body = '${name.isEmpty ? upcomingHolidayName : name}. '
        'No classes that day.';

    await _db.insertNotification(
      NotificationsTableCompanion(
        id: drift.Value(_uuid.v4()),
        academiaEmail: drift.Value(academiaEmail),
        type: const drift.Value('holiday_alert'),
        title: drift.Value(title),
        body: drift.Value(body),
        dataJson: drift.Value(
            jsonEncode({'holiday': upcomingHolidayName, 'date': dateStr})),
        read: const drift.Value(0),
        createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );

    await _notifPlugin.show(
      'holiday_alert'.hashCode,
      title,
      body,
      _notifDetails,
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// A course's name for a notification, falling back to its code.
  static String _name(AttendanceInput r) {
    final t = r.courseTitle.trim();
    return t.isEmpty ? r.courseCode : tidyTitle(t);
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
}
