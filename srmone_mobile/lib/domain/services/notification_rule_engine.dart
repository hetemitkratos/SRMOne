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
    if (records.isEmpty) return;

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
  /// attendance threshold, respecting 6h/18h fingerprint deduplication.
  Future<void> maybeNotifyLowAttendance(
    String academiaEmail,
    List<AttendanceInput> records, {
    double threshold = 75.0,
    bool alertEnabled = true,
  }) async {
    if (!alertEnabled) return;

    final effectiveThreshold = threshold > 0 ? threshold : 75.0;
    final below = records
        .where((r) => r.attendancePct < effectiveThreshold)
        .toList()
      ..sort((a, b) => a.courseCode.compareTo(b.courseCode));

    if (below.isEmpty) return;

    // Build deterministic fingerprint
    final fingerprint = below
        .map((r) => '${r.courseCode}:${r.attendancePct.round()}')
        .join(',');

    // Check last 'low_attendance' notification
    final recent = await _db.getRecentNotificationsByType(
      academiaEmail,
      'low_attendance',
      limit: 1,
    );

    if (recent.isNotEmpty) {
      final last = recent.first;
      final lastMs = last.createdAt;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedH = (nowMs - lastMs) / (1000 * 3600);

      // Suppress if < 6 hours old
      if (elapsedH < 6) return;

      // Suppress if same fingerprint and < 18 hours old
      final lastData = jsonDecode(last.dataJson) as Map<String, dynamic>;
      final lastFingerprint = lastData['fingerprint'] as String? ?? '';
      if (lastFingerprint == fingerprint && elapsedH < 18) return;
    }

    // Insert notification to database
    final body =
        '${below.length} subject(s) below ${effectiveThreshold.toStringAsFixed(0)}%: '
        '${below.map((r) => r.courseCode).join(', ')}. '
        'Check the attendance page for details.';

    await _db.insertNotification(
      NotificationsTableCompanion(
        id: drift.Value(_uuid.v4()),
        academiaEmail: drift.Value(academiaEmail),
        type: const drift.Value('low_attendance'),
        title: const drift.Value('Low Attendance Alert'),
        body: drift.Value(body),
        dataJson: drift.Value(jsonEncode({'fingerprint': fingerprint})),
        read: const drift.Value(0),
        createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );

    // Fire native OS notification
    await _notifPlugin.show(
      'low_attendance'.hashCode,
      'Low Attendance Alert',
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

    const title = 'Welcome to SRM One! 🎉';
    const body = 'Your attendance, marks, and timetable are now syncing. '
        'Pull down to refresh anytime!';

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

  /// Scans today through today+7 for upcoming holidays.
  /// Fires a notification if found and no unread holiday_alert exists.
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

    // Check if there is already an unread holiday_alert
    final existing = await _db.getRecentNotificationsByType(
      academiaEmail,
      'holiday_alert',
      limit: 5,
    );
    final hasUnread = existing.any((n) => (n.read) == 0);
    if (hasUnread) return;

    final dateStr = CalendarDayResolver.localDateKey(upcomingDate!);
    final body = '$upcomingHolidayName on $dateStr — enjoy your break!';

    await _db.insertNotification(
      NotificationsTableCompanion(
        id: drift.Value(_uuid.v4()),
        academiaEmail: drift.Value(academiaEmail),
        type: const drift.Value('holiday_alert'),
        title: const drift.Value('📅 Upcoming Holiday'),
        body: drift.Value(body),
        dataJson: drift.Value(
            jsonEncode({'holiday': upcomingHolidayName, 'date': dateStr})),
        read: const drift.Value(0),
        createdAt: drift.Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );

    await _notifPlugin.show(
      'holiday_alert'.hashCode,
      '📅 Upcoming Holiday',
      body,
      _notifDetails,
    );
  }
}
