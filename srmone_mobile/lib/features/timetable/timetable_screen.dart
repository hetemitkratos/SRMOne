// lib/features/timetable/timetable_screen.dart
// Timetable as a clean day timeline: a slim header with Share, one compact
// Day 1–5 switcher (with this week's dates), then the day's classes with
// times on the left, back-to-back periods merged, breaks as gaps and a
// "now" line. Tapping a class opens its details; swiping changes the day.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/calendar_day_resolver.dart';
import '../../domain/services/day_timeline.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import '../../domain/services/timetable_schedule.dart';
import '../../main.dart';
import '../auth/auth_controller.dart';
import '../faculty/faculty_avatar.dart';
import 'widgets/exportable_timetable_poster.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';
import '../shared/ui/srm_ui.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  /// The day order shown (1–5), or null for today's.
  int? _picked;
  bool _exporting = false;
  bool _showCourses = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';

    if (email.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view timetable.')),
      );
    }

    final courses = ref.watch(timetableCoursesProvider);
    final calendarMap = ref.watch(calendarMapProvider(currentSemester()));
    final now = DateTime.now();
    final todayStatus = CalendarDayResolver.getDayStatus(calendarMap, now);
    final todayOrder =
        todayStatus.isWorkingDay ? todayStatus.dayOrderNum : null;
    final day = _picked ?? todayOrder ?? 1;

    final colors =
        courseColorMap(courses.map((c) => c['courseCode']?.toString() ?? ''));
    final c = SrmColors.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(appRefresherProvider).refresh(waitForDetails: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: staggeredEntrance(context, [
            PageHeader(
              title: 'Timetable',
              subtitle: _statusLine(todayStatus, courses),
              actions: [
                if (courses.isNotEmpty)
                  HeaderAction(
                    label: _exporting ? 'Making…' : 'Share',
                    icon: LucideIcons.share2,
                    onPressed: _exporting ? null : () => _export(email),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const SyncSectionNotice(
              sections: [SyncSection.timetable],
              what: 'the timetable',
            ),
            if (courses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: EmptyPanel(
                  illustration: AssetPaths.studying,
                  title: 'No timetable data yet',
                  message: 'Pull down to refresh from the portal.',
                ),
              )
            else ...[
              _DaySwitcher(
                selected: day,
                today: todayOrder,
                dates: _nextDates(calendarMap, now),
                onPick: (d) => setState(() => _picked = d),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() < 300) return;
                  setState(
                      () => _picked = (day + (v < 0 ? 1 : -1)).clamp(1, 5));
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(day),
                    child: _DayTimeline(
                      dayLabel: 'Day $day',
                      courses: courses,
                      colors: colors,
                      now: day == todayOrder ? now : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _allCourses(context, c, courses, colors),
            ],
          ]),
        ),
      ),
    );
  }

  /// "Day 5 today · 3 classes", or why there are no classes today.
  String _statusLine(DayStatus s, List<Map<String, dynamic>> courses) {
    if (s.isHoliday) {
      return s.event.isNotEmpty ? 'Today: ${s.event}' : 'Holiday today';
    }
    if (s.isWeekend) return 'Weekend, no classes today';
    if (!s.isWorkingDay) return "Today's day order isn't published yet";
    final blocks =
        buildDayTimeline(TimetableSchedule.slotsForDay(courses, s.dayLabel))
            .whereType<ClassBlock>()
            .length;
    return '${s.dayLabel} today · $blocks class${blocks == 1 ? '' : 'es'}';
  }

  /// Day order (1–5) → the next date (today or later) it falls on, from
  /// the calendar, looking up to six weeks ahead.
  Map<int, DateTime> _nextDates(Map<String, CalendarEntry> cal, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final out = <int, DateTime>{};
    for (var i = 0; i < 42 && out.length < 5; i++) {
      final d = DateTime(today.year, today.month, today.day + i);
      final s = CalendarDayResolver.getDayStatus(cal, d);
      if (s.isWorkingDay && s.dayOrderNum != null) {
        out.putIfAbsent(s.dayOrderNum!, () => d);
      }
    }
    return out;
  }

  Future<void> _export(String email) async {
    setState(() => _exporting = true);
    try {
      final db = ref.read(appDatabaseProvider);
      final profile = await db.getStudentProfile(email);
      if (!mounted) return;
      await ExportableTimetablePoster.exportAndShare(
        context,
        studentName: profile?.name ?? 'Student',
        regNumber: profile?.regNumber ?? '',
        batch: ref.read(timetableProvider).valueOrNull?.batch ?? '',
        courses: ref.read(timetableCoursesProvider),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// "All courses", collapsed by default.
  Widget _allCourses(BuildContext context, SrmColors c,
      List<Map<String, dynamic>> courses, Map<String, Color> colors) {
    return SrmPanel(
      padding: EdgeInsets.zero,
      radius: SrmRadii.card,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _showCourses = !_showCourses),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              child: Row(
                children: [
                  Icon(LucideIcons.bookOpen, size: 18, color: c.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All courses (${courses.length})',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: c.text),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _showCourses ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child:
                        Icon(LucideIcons.chevronDown, size: 20, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_showCourses
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      for (final course in courses)
                        _CourseRow(
                          course: course,
                          color: colors[course['courseCode']
                                  ?.toString()
                                  .toUpperCase()] ??
                              SrmPalette.mint,
                        ),
                      const SizedBox(height: 6),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Day switcher ────────────────────────────────────────────────────────────

/// Day 1–5 in one rounded track; the selection slides between them.
class _DaySwitcher extends StatelessWidget {
  final int selected;
  final int? today;
  final Map<int, DateTime> dates;
  final ValueChanged<int> onPick;

  const _DaySwitcher({
    required this.selected,
    required this.today,
    required this.dates,
    required this.onPick,
  });

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return Container(
      height: 62,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1 + (selected - 1) * 0.5, 0),
            child: FractionallySizedBox(
              widthFactor: 0.2,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: c.hero,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var d = 1; d <= 5; d++)
                Expanded(child: _segment(context, c, d)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, SrmColors c, int d) {
    final isSel = d == selected;
    final date = dates[d];
    final sub =
        date == null ? '' : '${_weekdays[date.weekday - 1]} ${date.day}';
    final label = sub.isEmpty ? 'No date' : sub;
    return Semantics(
      button: true,
      selected: isSel,
      label:
          'Day $d${sub.isEmpty ? '' : ', $sub'}${d == today ? ', today' : ''}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onPick(d),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Balances the today dot so the label stays centred.
                  if (d == today) const SizedBox(width: 9),
                  Text(
                    'Day $d',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isSel ? c.onHero : c.text,
                    ),
                  ),
                  if (d == today) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: SrmPalette.terracotta,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isSel ? c.onHero.withAlpha(170) : c.faint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Timeline ────────────────────────────────────────────────────────────────

class _DayTimeline extends StatelessWidget {
  final String dayLabel;
  final List<Map<String, dynamic>> courses;
  final Map<String, Color> colors;

  /// The current time when this is today's view, for the "now" line.
  final DateTime? now;

  const _DayTimeline({
    required this.dayLabel,
    required this.courses,
    required this.colors,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final entries =
        buildDayTimeline(TimetableSchedule.slotsForDay(courses, dayLabel));
    if (entries.isEmpty) {
      return EmptyPanel(
        illustration: AssetPaths.aDayOff,
        title: 'Free day!',
        message: 'No classes scheduled for $dayLabel.',
      );
    }

    final byCode = {
      for (final c in courses) c['courseCode']?.toString() ?? '': c,
    };
    final nowMin = now == null ? null : now!.hour * 60 + now!.minute;

    // Where the "now" line goes: before the first entry that starts after
    // now, unless now falls inside a class (which is highlighted instead).
    final blocks = entries.whereType<ClassBlock>();
    final inClass = nowMin != null && blocks.any((b) => b.contains(nowMin));
    int? nowIndex;
    if (nowMin != null && !inClass) {
      final first = blocks.first.start;
      final last = blocks.last.end;
      if (first != null &&
          last != null &&
          nowMin >= first - 60 &&
          nowMin < last) {
        nowIndex = entries.indexWhere((e) => switch (e) {
              ClassBlock(:final start) => start != null && start > nowMin,
              BreakGap(:final end) => end > nowMin,
            });
      }
    }

    return Column(
      children: [
        for (final (i, e) in entries.indexed) ...[
          if (i == nowIndex) _NowLine(minutes: nowMin!),
          switch (e) {
            ClassBlock() => _ClassRow(
                block: e,
                course: byCode[e.courseCode] ?? const {},
                color: colors[e.courseCode.toUpperCase()] ?? SrmPalette.mint,
                nowMin: nowMin,
              ),
            BreakGap() => _BreakRow(gap: e),
          },
        ],
      ],
    );
  }
}

const _timeColumn = 62.0;

class _ClassRow extends StatelessWidget {
  final ClassBlock block;
  final Map<String, dynamic> course;
  final Color color;
  final int? nowMin;

  const _ClassRow({
    required this.block,
    required this.course,
    required this.color,
    required this.nowMin,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final room = course['roomNo']?.toString().trim() ?? '';
    final faculty = (course['facultyName']?.toString() ?? '')
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .trim();
    final live = nowMin != null && block.contains(nowMin!);
    final done = nowMin != null && block.end != null && nowMin! >= block.end!;
    final start = block.start;
    final end = block.end;
    const ink = SrmPalette.ink;

    return Opacity(
      opacity: done ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: _timeColumn,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        start == null ? '—' : formatClock(start, suffix: false),
                        style: TextStyle(
                          fontFamily: SrmFonts.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: c.text,
                        ),
                      ),
                      if (start != null)
                        Text(
                          start < 720 ? 'AM' : 'PM',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: c.faint),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Material(
                  color: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: live ? ink : Colors.black.withAlpha(13),
                      width: live ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showClassSheet(context, block, course, color),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                block.courseCode.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: SrmFonts.mono,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: ink.withAlpha(150),
                                ),
                              ),
                              const Spacer(),
                              if (live)
                                const SoftPill(
                                  label: 'NOW',
                                  icon: LucideIcons.radio,
                                  background: ink,
                                  foreground: Colors.white,
                                )
                              else if (block.periods > 1)
                                SoftPill(
                                  label: '${block.periods} periods',
                                  background: Colors.white.withAlpha(150),
                                  foreground: ink,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tidyTitle(block.courseTitle.isNotEmpty
                                ? block.courseTitle
                                : block.courseCode),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              height: 1.25,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (start != null && end != null)
                                SoftPill(
                                  label: formatRange(start, end),
                                  icon: LucideIcons.clock,
                                  background: Colors.white.withAlpha(150),
                                  foreground: ink,
                                ),
                              if (room.isNotEmpty)
                                SoftPill(
                                  label: room,
                                  icon: LucideIcons.mapPin,
                                  background: Colors.white.withAlpha(150),
                                  foreground: ink,
                                ),
                            ],
                          ),
                          if (faculty.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                FacultyAvatar(facultyName: faculty, radius: 11),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    faculty,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: ink.withAlpha(190),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (live && start != null && end != null) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (nowMin! - start) / (end - start),
                                minHeight: 4,
                                color: ink,
                                backgroundColor: Colors.white.withAlpha(128),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakRow extends StatelessWidget {
  final BreakGap gap;
  const _BreakRow({required this.gap});

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const SizedBox(width: _timeColumn),
          Icon(LucideIcons.coffee, size: 14, color: c.faint),
          const SizedBox(width: 8),
          Text(
            'Break · ${formatDuration(gap.minutes)}',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: c.faint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: c.border),
          ),
        ],
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  final int minutes;
  const _NowLine({required this.minutes});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Now, ${formatClock(minutes)}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: _timeColumn,
                child: Text(
                  formatClock(minutes),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: SrmPalette.terracottaText,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: SrmPalette.terracotta,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Container(height: 1.5, color: SrmPalette.terracotta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseRow extends StatelessWidget {
  final Map<String, dynamic> course;
  final Color color;
  const _CourseRow({required this.course, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    String v(String k) => course[k]?.toString().trim() ?? '';
    return InkWell(
      onTap: () => _showClassSheet(
        context,
        null,
        course,
        color,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tidyTitle(v('courseTitle')),
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: c.text),
                  ),
                  Text(
                    [v('courseCode'), if (v('roomNo').isNotEmpty) v('roomNo')]
                        .join('  ·  '),
                    style: TextStyle(fontSize: 12, color: c.faint),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: c.faint),
          ],
        ),
      ),
    );
  }
}

// ─── Class sheet ─────────────────────────────────────────────────────────────

/// Details for a course: faculty, room, slot, credits, this block's time and
/// the student's attendance in it.
void _showClassSheet(BuildContext context, ClassBlock? block,
    Map<String, dynamic> course, Color color) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ClassSheet(block: block, course: course, color: color),
  );
}

class _ClassSheet extends ConsumerWidget {
  final ClassBlock? block;
  final Map<String, dynamic> course;
  final Color color;

  const _ClassSheet(
      {required this.block, required this.course, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SrmColors.of(context);
    String v(String k) => course[k]?.toString().trim() ?? '';
    final code =
        v('courseCode').isNotEmpty ? v('courseCode') : block?.courseCode ?? '';
    final title = tidyTitle(v('courseTitle').isNotEmpty
        ? v('courseTitle')
        : block?.courseTitle ?? code);
    final records = ref.watch(attendanceRecordsProvider).valueOrNull ??
        const <AttendanceCacheData>[];
    final attendance = records
        .where((r) => r.courseCode.trim().toUpperCase() == code.toUpperCase())
        .firstOrNull;
    final faculty = v('facultyName');
    final slot = v('slot').replaceAll(RegExp(r'-+$'), '');

    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration:
                    BoxDecoration(color: c.track, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: c.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: c.text)),
              ),
            ],
          ),
        );

    return SizedBox(
      width: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CodePill(code),
                  if (slot.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    SoftPill(
                      label: 'SLOT $slot',
                      background: c.track,
                      foreground: c.muted,
                    ),
                  ],
                  const Spacer(),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontFamily: SrmFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  height: 1.2,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 18),
              if (block?.start != null && block?.end != null)
                row(
                  LucideIcons.clock,
                  [
                    formatRange(block!.start!, block!.end!),
                    if (block!.periods > 1) '${block!.periods} periods',
                  ].join('  ·  '),
                ),
              if (v('roomNo').isNotEmpty) row(LucideIcons.mapPin, v('roomNo')),
              if (v('courseType').isNotEmpty || v('credit').isNotEmpty)
                row(
                  LucideIcons.bookOpen,
                  [
                    if (v('courseType').isNotEmpty) v('courseType'),
                    if (v('credit').isNotEmpty) '${v('credit')} credits',
                  ].join('  ·  '),
                ),
              if (faculty.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      FacultyAvatar(facultyName: faculty, radius: 17),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          faculty.replaceAll(RegExp(r'\(.*?\)'), '').trim(),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: c.text),
                        ),
                      ),
                      Text('Tap photo for profile',
                          style: TextStyle(fontSize: 11, color: c.faint)),
                    ],
                  ),
                ),
              if (attendance != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.track,
                    borderRadius: BorderRadius.circular(SrmRadii.card),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Attendance',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: c.text)),
                          const Spacer(),
                          Text(
                            '${attendance.attendancePct.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontFamily: SrmFonts.display,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              color: c.text,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SrmProgressBar(
                        value: attendance.attendancePct / 100,
                        color: attendanceBarColor(attendance.attendancePct),
                        height: 8,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${attendance.hoursConducted - attendance.hoursAbsent} of '
                        '${attendance.hoursConducted} hours attended',
                        style: TextStyle(fontSize: 12, color: c.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
