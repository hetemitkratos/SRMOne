// lib/features/marks/marks_screen.dart
// Internal marks, one card per course. Academia's test-by-test marks and the
// Student Portal's internal total stay separate records (Bug Fix #6) and are
// shown side by side, each labelled with where it came from. The app does
// not fetch semester grades, so there is no tab for them.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import '../auth/auth_controller.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';
import '../shared/ui/srm_ui.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    if (authState is! Authenticated) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view marks.')),
      );
    }

    final courses = ref.watch(_courseMarksProvider);
    final c = SrmColors.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(appRefresherProvider).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const HeroBanner(
              title: 'Marks',
              subtitle:
                  'Review your test scores and track your internal marks.',
              illustration: AssetPaths.success,
            ),
            const SizedBox(height: 16),
            const SyncSectionNotice(
              sections: [SyncSection.marks, SyncSection.studentPortalMarks],
              what: 'marks',
            ),
            if (courses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: EmptyPanel(
                  illustration: AssetPaths.learning,
                  title: 'No internal marks published yet',
                  message: 'Pull down to refresh.',
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: SrmPalette.mint, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tests from Academia, internal totals from the Student Portal',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.muted),
                      ),
                    ),
                  ],
                ),
              ),
              for (final course in courses)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CourseMarksCard(course: course),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One course, as the web's marks cards: code and type pills, the title,
/// the portal's internal total, and the Academia tests (tap to show them).
class _CourseMarksCard extends StatefulWidget {
  final CourseMarks course;
  const _CourseMarksCard({required this.course});

  @override
  State<_CourseMarksCard> createState() => _CourseMarksCardState();
}

class _CourseMarksCardState extends State<_CourseMarksCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final course = widget.course;
    final total = course.portalTotal;
    final tests = course.academiaTests;
    final testCount = '${tests.length} test${tests.length == 1 ? '' : 's'}';

    return SrmPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: tests.isEmpty ? null : () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CodePill(course.courseCode),
                      if (course.courseType.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: SoftPill(
                            label: course.courseType,
                            background: c.track,
                            foreground: c.muted,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (tests.isNotEmpty) ...[
                        SoftPill(
                          label: testCount,
                          background: c.track,
                          foreground: c.faint,
                        ),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                                color: c.track, shape: BoxShape.circle),
                            child: Icon(LucideIcons.chevronDown,
                                size: 18, color: c.muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    course.courseTitle.isNotEmpty
                        ? course.courseTitle
                        : course.courseCode,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      height: 1.25,
                      color: c.text,
                    ),
                  ),
                  if (total != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            'INTERNAL TOTAL · STUDENT PORTAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: c.faint,
                            ),
                          ),
                        ),
                        _score(c, _fmt(total.scored), _fmt(total.max), 26),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SrmProgressBar(
                      value: total.scored / total.max,
                      color: SrmPalette.mint,
                      height: 8,
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        for (final (i, t) in tests.indexed) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _testBox(c, t, i),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _testBox(SrmColors c, Map<String, dynamic> t, int i) {
    final scored = num.tryParse('${t['scored']}');
    final max = num.tryParse('${t['maxMarks']}');
    final name = '${t['testName'] ?? 'Test ${i + 1}'}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.page == SrmPalette.cream ? const Color(0xFFF8FAFC) : c.track,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: c.muted,
                  ),
                ),
              ),
              _score(c, '${t['scored'] ?? '—'}', '${t['maxMarks'] ?? '—'}', 22),
            ],
          ),
          if (scored != null && max != null && max > 0) ...[
            const SizedBox(height: 10),
            SrmProgressBar(
              value: scored / max,
              color: SrmPalette.mint,
              height: 6,
            ),
          ],
        ],
      ),
    );
  }

  /// "18 / 20" with the score large, as on the web.
  static Widget _score(SrmColors c, String scored, String max, double size) {
    return Text.rich(TextSpan(children: [
      TextSpan(
        text: scored,
        style: TextStyle(
          fontFamily: SrmFonts.display,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: 1,
          color: c.text,
        ),
      ),
      TextSpan(
        text: ' / $max',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: c.faint,
        ),
      ),
    ]));
  }

  /// 18.7 → "18.7", 20.0 → "20".
  static String _fmt(double v) => v
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
