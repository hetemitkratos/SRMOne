// lib/features/marks/marks_screen.dart
// Internal marks, one card per course. Academia's test-by-test marks and the
// Student Portal's internal total stay separate records (Bug Fix #6) and are
// shown side by side, each labelled with where it came from. The app does
// not fetch semester grades, so there is no tab for them.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../auth/auth_controller.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';
import '../shared/refreshable_empty.dart';

/// One course's internal marks from both portals.
class CourseMarks {
  final String courseCode;
  final String courseTitle;
  final String courseType;

  /// Academia's individual tests (name, scored, max), possibly empty.
  final List<Map<String, dynamic>> academiaTests;

  /// The Student Portal's internal total, if it has one for this course.
  final ({double scored, double max})? portalTotal;

  const CourseMarks({
    required this.courseCode,
    required this.courseTitle,
    required this.courseType,
    required this.academiaTests,
    required this.portalTotal,
  });
}

/// Groups [marks] rows by course code, adding a title from [titles] (by
/// upper-case course code) when the marks row has none.
List<CourseMarks> groupCourseMarks(
    List<MarksCacheData> marks, Map<String, String> titles) {
  final byCode = <String, List<MarksCacheData>>{};
  for (final m in marks) {
    byCode.putIfAbsent(m.courseCode.trim().toUpperCase(), () => []).add(m);
  }
  final out = <CourseMarks>[];
  for (final MapEntry(key: code, value: rows) in byCode.entries) {
    final academia = rows.where((m) => m.source != 'student_portal');
    final portal = rows.where((m) => m.source == 'student_portal');
    final title = rows
        .map((m) => m.courseTitle.trim())
        .firstWhere((t) => t.isNotEmpty, orElse: () => titles[code] ?? '');
    out.add(CourseMarks(
      courseCode: rows.first.courseCode.trim(),
      courseTitle: title,
      courseType: academia.isEmpty ? '' : academia.first.courseType,
      academiaTests: [for (final m in academia) ..._decodeTests(m.testsJson)],
      portalTotal: portal.isEmpty ? null : _portalTotal(portal.first.testsJson),
    ));
  }
  out.sort((a, b) => (a.courseTitle.isEmpty ? a.courseCode : a.courseTitle)
      .compareTo(b.courseTitle.isEmpty ? b.courseCode : b.courseTitle));
  return out;
}

List<Map<String, dynamic>> _decodeTests(String json) {
  try {
    return (jsonDecode(json) as List<dynamic>).cast<Map<String, dynamic>>();
  } catch (_) {
    return const [];
  }
}

({double scored, double max})? _portalTotal(String json) {
  for (final t in _decodeTests(json)) {
    final scored = num.tryParse('${t['scored']}');
    final max = num.tryParse('${t['maxMarks']}');
    if (scored != null && max != null && max > 0) {
      return (scored: scored.toDouble(), max: max.toDouble());
    }
  }
  return null;
}

/// Course titles by upper-case code, from attendance and the timetable.
final _courseTitlesProvider = Provider<Map<String, String>>((ref) {
  final titles = <String, String>{};
  for (final c in ref.watch(timetableCoursesProvider)) {
    final code = c['courseCode']?.toString().trim().toUpperCase() ?? '';
    final title = c['courseTitle']?.toString().trim() ?? '';
    if (code.isNotEmpty && title.isNotEmpty) titles[code] = title;
  }
  for (final a in ref.watch(attendanceRecordsProvider).valueOrNull ?? []) {
    final title = a.courseTitle.trim();
    if (title.isNotEmpty) titles[a.courseCode.trim().toUpperCase()] = title;
  }
  return titles;
});

final _courseMarksProvider = Provider<List<CourseMarks>>((ref) {
  final marks = ref.watch(marksProvider).valueOrNull ?? const [];
  return groupCourseMarks(marks, ref.watch(_courseTitlesProvider));
});

class MarksScreen extends ConsumerWidget {
  const MarksScreen({super.key});

  static const _green = Color(0xFF2D6A4F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    if (authState is! Authenticated) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view marks.')),
      );
    }

    final courses = ref.watch(_courseMarksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Internal Marks')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(appRefresherProvider).refresh();
        },
        child: courses.isEmpty
            ? RefreshableEmpty(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(AssetPaths.learning, height: 140),
                    const SizedBox(height: 16),
                    const Text(
                      'No internal marks published yet.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pull down to refresh',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: courses.length,
                itemBuilder: (context, index) =>
                    _courseCard(theme, courses[index]),
              ),
      ),
    );
  }

  Widget _courseCard(ThemeData theme, CourseMarks course) {
    final total = course.portalTotal;
    final subtitle = [
      course.courseCode,
      if (course.courseType.isNotEmpty) course.courseType,
    ].join(' • ');

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _green.withAlpha(30),
                  child: const Icon(LucideIcons.graduationCap,
                      color: _green, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.courseTitle.isNotEmpty
                            ? course.courseTitle
                            : course.courseCode,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (total != null)
                  Text(
                    '${_fmt(total.scored)}/${_fmt(total.max)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _green,
                    ),
                  ),
              ],
            ),
            if (total != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (total.scored / total.max).clamp(0.0, 1.0),
                  minHeight: 6,
                  color: _green,
                  backgroundColor: _green.withAlpha(30),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Internal total · Student Portal',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            if (course.academiaTests.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Tests · Academia',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              _testsTable(theme, course.academiaTests),
            ],
          ],
        ),
      ),
    );
  }

  Widget _testsTable(ThemeData theme, List<Map<String, dynamic>> tests) {
    TableRow row(List<String> cells, {bool header = false}) => TableRow(
          decoration: header
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor.withAlpha(50)),
                  ),
                )
              : null,
          children: [
            for (final (i, text) in cells.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  text,
                  textAlign: const [
                    TextAlign.left,
                    TextAlign.center,
                    TextAlign.right,
                  ][i],
                  style: TextStyle(
                    fontSize: header ? 12 : 13,
                    fontWeight:
                        header || i == 1 ? FontWeight.bold : FontWeight.normal,
                    color: header || i == 2
                        ? Colors.grey
                        : (i == 1 ? _green : null),
                  ),
                ),
              ),
          ],
        );

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
      },
      children: [
        row(['Assessment', 'Scored', 'Max'], header: true),
        for (final t in tests)
          row([
            '${t['testName'] ?? 'Test'}',
            '${t['scored'] ?? '-'}',
            '${t['maxMarks'] ?? '-'}',
          ]),
      ],
    );
  }

  /// 18.7 → "18.7", 20.0 → "20".
  static String _fmt(double v) => v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
