// lib/features/widgets_and_calendar_sync/home_widget_sync.dart
// Pushes Today's Day Order, Next Class, and Overall Attendance %
// to iOS WidgetKit and Android AppWidget via home_widget package.

import 'package:home_widget/home_widget.dart';
import '../../core/database/app_database.dart';
import '../../domain/services/attendance_planner_math.dart';

class HomeWidgetSync {
  static const String appGroupId = 'group.in.srmone.mobile';
  static const String androidWidgetName = 'SrmOneWidgetProvider';
  static const String iOSWidgetName = 'SrmOneWidget';

  /// Updates home screen widgets with current local state.
  static Future<void> updateWidgets({
    required String dayOrder,
    required String nextClass,
    required List<AttendanceCacheData> attendanceRecords,
  }) async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);

      // Compute overall percentage
      final inputs = attendanceRecords
          .map((r) => AttendanceInput(
                courseCode: r.courseCode,
                courseTitle: r.courseTitle,
                hoursConducted: r.hoursConducted,
                hoursAbsent: r.hoursAbsent,
                attendancePct: r.attendancePct,
              ))
          .toList();

      final summary = computeAttendanceSummary(inputs);
      final pctString = summary.unweightedMeanPct > 0
          ? '${summary.unweightedMeanPct.toStringAsFixed(1)}%'
          : '--';

      // Save key-values to native shared preferences
      await HomeWidget.saveWidgetData<String>('day_order', dayOrder);
      await HomeWidget.saveWidgetData<String>('next_class', nextClass);
      await HomeWidget.saveWidgetData<String>('attendance_pct', pctString);
      await HomeWidget.saveWidgetData<String>(
        'updated_at',
        DateTime.now().toIso8601String(),
      );

      // Trigger native widget refresh
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (_) {
      // Graceful fallback if widget is not installed on launcher
    }
  }
}
