// lib/features/widgets_and_calendar_sync/native_calendar_exporter.dart
// 1-Tap exporter for syncing resolved academic timetable lectures and
// university holidays into native device calendar (Apple / Google Calendar).

import 'package:device_calendar/device_calendar.dart';
import '../../domain/services/calendar_day_resolver.dart';

class NativeCalendarExporter {
  final DeviceCalendarPlugin _plugin;

  NativeCalendarExporter({DeviceCalendarPlugin? plugin})
      : _plugin = plugin ?? DeviceCalendarPlugin();

  /// Requests calendar permissions and returns true if granted.
  Future<bool> requestPermissions() async {
    var permissionsGranted = await _plugin.hasPermissions();
    if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
      permissionsGranted = await _plugin.requestPermissions();
      if (!permissionsGranted.isSuccess || !permissionsGranted.data!) {
        return false;
      }
    }
    return permissionsGranted.data == true;
  }

  /// Exports academic holidays into the user's primary device calendar.
  Future<int> exportHolidays({
    required List<CalendarEntry> calendarEntries,
  }) async {
    final hasPerm = await requestPermissions();
    if (!hasPerm) return 0;

    final calendarsResult = await _plugin.retrieveCalendars();
    if (!calendarsResult.isSuccess ||
        calendarsResult.data == null ||
        calendarsResult.data!.isEmpty) {
      return 0;
    }

    // Pick first writable calendar (or default)
    final targetCalendar = calendarsResult.data!.firstWhere(
      (c) => c.isReadOnly == false,
      orElse: () => calendarsResult.data!.first,
    );

    int count = 0;
    for (final entry in calendarEntries) {
      if (entry.event.isEmpty) continue;
      final isHol = entry.event.toLowerCase().contains('holiday');
      if (!isHol) continue;

      final parts = entry.date.split('-');
      if (parts.length < 3) continue;

      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2]);
      if (y == null || m == null || d == null) continue;

      final start = DateTime(y, m, d, 9, 0);
      final end = DateTime(y, m, d, 18, 0);

      final event = Event(
        targetCalendar.id,
        title: 'SRM: ${entry.event}',
        description: 'University Holiday recorded by SRMOne',
        start: TZDateTime.from(start, local),
        end: TZDateTime.from(end, local),
        allDay: true,
      );

      final res = await _plugin.createOrUpdateEvent(event);
      if (res?.isSuccess == true) {
        count++;
      }
    }

    return count;
  }
}
