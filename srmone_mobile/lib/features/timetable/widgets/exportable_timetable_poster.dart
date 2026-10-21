// lib/features/timetable/widgets/exportable_timetable_poster.dart
// The shareable timetable image: a week grid (Day 1–5 by hour, one colour
// per course) under a black header, with a legend of courses, in the app's
// cream and ink look. Rendered offscreen at its own 1080 px width.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/asset_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/services/current_class_detector.dart';
import '../../../domain/services/day_timeline.dart';
import '../../../domain/services/timetable_schedule.dart';
import '../../shared/ui/srm_ui.dart';

/// The poster's width in logical pixels; captured at 2x.
const posterWidth = 1080.0;

class ExportableTimetablePoster extends StatelessWidget {
  final String studentName;
  final String regNumber;
  final String batch;

  /// The timetable courses, as stored (`courseCode`, `courseTitle`,
  /// `facultyName`, `roomNo`, `schedule`).
  final List<Map<String, dynamic>> courses;

  const ExportableTimetablePoster({
    super.key,
    required this.studentName,
    required this.regNumber,
    required this.batch,
    required this.courses,
  });

  /// Renders the poster as a PNG and opens the share sheet.
  static Future<void> exportAndShare(
    BuildContext context, {
    required String studentName,
    required String regNumber,
    required String batch,
    required List<Map<String, dynamic>> courses,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final poster = Theme(
      data: srmLightTheme(),
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: SrmPalette.cream,
            child: ExportableTimetablePoster(
              studentName: studentName,
              regNumber: regNumber,
              batch: batch,
              courses: courses,
            ),
          ),
        ),
      ),
    );

    try {
      // Laid out at the poster's own width (not the phone's), so nothing
      // overflows; the height follows the content.
      final bytes = await ScreenshotController().captureFromLongWidget(
        poster,
        pixelRatio: 2,
        delay: const Duration(milliseconds: 300),
        constraints:
            const BoxConstraints(minWidth: posterWidth, maxWidth: posterWidth),
      );

      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/SRMOne_Timetable_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '$studentName - SRM One timetable',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text("Couldn't create the timetable image: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors =
        courseColorMap(courses.map((c) => c['courseCode']?.toString() ?? ''));
    final days = [
      for (var d = 1; d <= 5; d++)
        TimetableSchedule.slotsForDay(courses, 'Day $d'),
    ];

    // Hour columns: every period any day uses, with its timing.
    final hours = <int, String>{};
    for (final day in days) {
      for (final s in day) {
        hours.putIfAbsent(s.hourIndex, () => s.timing);
      }
    }
    final columns = hours.keys.toList()..sort();

    return Container(
      width: posterWidth,
      color: SrmPalette.cream,
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          const SizedBox(height: 28),
          if (columns.isEmpty)
            const Text('No classes in the timetable yet.',
                style: TextStyle(fontSize: 20, color: SrmPalette.slate500))
          else
            _grid(columns, hours, days, colors),
          const SizedBox(height: 28),
          _legend(colors),
          const SizedBox(height: 24),
          const Text(
            'Made with SRM One',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SrmPalette.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final details = [
      if (regNumber.isNotEmpty) regNumber,
      if (batch.isNotEmpty) 'Batch $batch',
    ].join('  •  ');
    return Container(
      padding: const EdgeInsets.fromLTRB(36, 32, 36, 32),
      decoration: BoxDecoration(
        color: SrmPalette.ink,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WEEKLY TIMETABLE',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: SrmPalette.mint,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  studentName,
                  style: const TextStyle(
                    fontFamily: SrmFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 44,
                    height: 1.05,
                    letterSpacing: -1,
                    color: Colors.white,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    details,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha(170),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 24),
          Column(
            children: [
              Image.asset(AssetPaths.logo, width: 72, height: 72),
              const SizedBox(height: 8),
              const Text(
                'SRM ONE',
                style: TextStyle(
                  fontFamily: SrmFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _grid(
    List<int> columns,
    Map<int, String> hours,
    List<List<TimetableSlotWithTiming>> days,
    Map<String, Color> colors,
  ) {
    const dayWidth = 92.0;
    const rowHeight = 92.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          // Hour headings.
          Row(
            children: [
              const SizedBox(width: dayWidth),
              for (final h in columns)
                Expanded(
                  child: Builder(builder: (_) {
                    final t = CurrentClassDetector.parseTiming(hours[h]!);
                    return Column(
                      children: [
                        Text(
                          t == null
                              ? hours[h]!
                              : formatClock(t.$1, suffix: false),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: SrmPalette.ink,
                          ),
                        ),
                        if (t != null)
                          Text(
                            formatClock(t.$2, suffix: false),
                            style: const TextStyle(
                                fontSize: 12, color: SrmPalette.slate400),
                          ),
                      ],
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, slots) in days.indexed) ...[
            if (i > 0) const SizedBox(height: 8),
            SizedBox(
              height: rowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: dayWidth,
                    child: Center(
                      child: Text(
                        'Day\n${i + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: SrmFonts.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          height: 1.1,
                          color: SrmPalette.ink,
                        ),
                      ),
                    ),
                  ),
                  ..._rowCells(columns, slots, colors),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One day's cells; consecutive periods of a course share one wide cell.
  List<Widget> _rowCells(
    List<int> columns,
    List<TimetableSlotWithTiming> slots,
    Map<String, Color> colors,
  ) {
    final byHour = {for (final s in slots) s.hourIndex: s};
    final rooms = {
      for (final c in courses)
        c['courseCode']?.toString() ?? '': c['roomNo']?.toString() ?? '',
    };
    final cells = <Widget>[];
    var i = 0;
    while (i < columns.length) {
      final s = byHour[columns[i]];
      var span = 1;
      while (s != null &&
          i + span < columns.length &&
          byHour[columns[i + span]]?.courseCode == s.courseCode) {
        span++;
      }
      cells.add(Expanded(
        flex: span,
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: s == null
              ? Container(
                  decoration: BoxDecoration(
                    color: SrmPalette.slate100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color:
                        colors[s.courseCode.toUpperCase()] ?? SrmPalette.mint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          s.courseCode,
                          style: const TextStyle(
                            fontFamily: SrmFonts.mono,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: SrmPalette.ink,
                          ),
                        ),
                      ),
                      if ((rooms[s.courseCode] ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            rooms[s.courseCode]!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: SrmPalette.ink.withAlpha(170),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ));
      i += span;
    }
    return cells;
  }

  Widget _legend(Map<String, Color> colors) {
    String v(Map<String, dynamic> c, String k) => c[k]?.toString().trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 20,
        children: [
          for (final c in courses)
            SizedBox(
              width: (posterWidth - 80 - 56 - 24) / 2,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: colors[v(c, 'courseCode').toUpperCase()],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tidyTitle(v(c, 'courseTitle')),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: SrmPalette.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            v(c, 'courseCode'),
                            if (v(c, 'roomNo').isNotEmpty) v(c, 'roomNo'),
                            if (v(c, 'facultyName').isNotEmpty)
                              v(c, 'facultyName')
                                  .replaceAll(RegExp(r'\(.*?\)'), '')
                                  .trim(),
                          ].join('  ·  '),
                          style: const TextStyle(
                            fontSize: 14,
                            color: SrmPalette.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
