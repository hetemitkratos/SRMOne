// lib/features/timetable/timetable_screen.dart
// Timetable, laid out like the web app's Timetable page: the hero with a
// poster download, Day 1–5 pills (swipe the list to change day), pastel
// class cards with live/up-next highlights, and the course details panel.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/calendar_day_resolver.dart';
import '../../domain/services/current_class_detector.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import '../../domain/services/timetable_schedule.dart';
import '../../main.dart';
import '../auth/auth_controller.dart';
import '../faculty/faculty_avatar.dart';
import 'widgets/exportable_timetable_poster.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';
import '../shared/ui/srm_ui.dart';

/// The web's per-course pastel cycle (`SLOT_COLORS`).
const _slotColors = [SrmPalette.mint, SrmPalette.lavender, SrmPalette.beige];

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  /// The day order shown (1–5), or null for today's.
  int? _picked;
  bool _exporting = false;

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
    final todayStatus =
        CalendarDayResolver.getDayStatus(calendarMap, DateTime.now());
    final todayOrder =
        todayStatus.isWorkingDay ? todayStatus.dayOrderNum : null;
    final day = _picked ?? todayOrder ?? 1;

    final colors = {
      for (final (i, c) in courses.indexed)
        c['courseCode']?.toString() ?? '': _slotColors[i % _slotColors.length],
    };

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(appRefresherProvider).refresh(waitForDetails: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            HeroBanner(
              title: 'Timetable',
              subtitle: 'Organize your week and plan your classes.',
              illustration: AssetPaths.timeManagement,
              action: courses.isEmpty
                  ? null
                  : HeroPillButton(
                      label: _exporting ? 'Generating…' : 'Share poster',
                      icon: LucideIcons.download,
                      light: true,
                      onPressed: _exporting ? null : () => _export(email),
                    ),
            ),
            const SizedBox(height: 16),
            const SyncSectionNotice(
              sections: [SyncSection.timetable],
              what: 'the timetable',
            ),
            if (courses.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: EmptyPanel(
                  illustration: AssetPaths.studying,
                  title: 'No timetable data yet',
                  message: 'Pull down to refresh from the portal.',
                ),
              )
            else ...[
              const SizedBox(height: 16),
              _todayBanner(context, todayStatus),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var d = 1; d <= 5; d++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _DayPill(
                          day: d,
                          selected: d == day,
                          today: d == todayOrder,
                          onTap: () => setState(() => _picked = d),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() < 300) return;
                  setState(
                      () => _picked = (day + (v < 0 ? 1 : -1)).clamp(1, 5));
                },
                child: _dayClasses(
                  context,
                  'Day $day',
                  courses,
                  colors,
                  isToday: day == todayOrder,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'SWIPE LEFT & RIGHT TO CHANGE DAYS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: SrmColors.of(context).faint,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _courseDetails(context, courses),
            ],
          ],
        ),
      ),
    );
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
        batch: ref.read(timetableProvider).valueOrNull?.batch ?? '1',
        schedule:
            TimetableSchedule.daySchedule(ref.read(timetableCoursesProvider)),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Today's status, as the web's TodayBanner.
  Widget _todayBanner(BuildContext context, DayStatus s) {
    final c = SrmColors.of(context);
    final (icon, title, text, bg) = s.isHoliday
        ? (
            LucideIcons.calendarX,
            s.event.isNotEmpty ? s.event : 'Holiday today',
            'No classes today. Enjoy your day off!',
            SrmPalette.terracotta.withAlpha(36),
          )
        : s.isWeekend
            ? (
                LucideIcons.sun,
                "It's the weekend",
                'Pick a day order below to preview it.',
                SrmPalette.lavender.withAlpha(110),
              )
            : s.isWorkingDay
                ? (
                    LucideIcons.calendarCheck,
                    'Today is ${s.dayLabel}',
                    'Your classes for today are selected below.',
                    SrmPalette.mint.withAlpha(110),
                  )
                : (
                    LucideIcons.info,
                    'Calendar day order unavailable',
                    "Today isn't in the academic calendar yet.",
                    c.track,
                  );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SrmRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.card, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: c.text),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: c.text)),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(fontSize: 12, color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayClasses(
    BuildContext context,
    String dayLabel,
    List<Map<String, dynamic>> courses,
    Map<String, Color> colors, {
    required bool isToday,
  }) {
    final slots = TimetableSchedule.slotsForDay(courses, dayLabel);
    if (slots.isEmpty) {
      return EmptyPanel(
        illustration: AssetPaths.aDayOff,
        title: 'Free day!',
        message: 'No classes scheduled for $dayLabel.',
      );
    }

    final classified = isToday
        ? CurrentClassDetector.classify(slots, dayLabel, DateTime.now())
        : [
            for (final s in slots)
              (
                s,
                const ClassTimeInfo(
                  state: ClassTimeState.future,
                  startMinutes: 0,
                  endMinutes: 0,
                ),
              ),
          ];
    final byCode = {
      for (final c in courses) c['courseCode']?.toString() ?? '': c,
    };

    return Column(
      children: [
        for (final (slot, info) in classified)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ClassCell(
              slot: slot,
              info: info,
              course: byCode[slot.courseCode] ?? const {},
              color: colors[slot.courseCode] ?? SrmPalette.mint,
            ),
          ),
      ],
    );
  }

  Widget _courseDetails(
      BuildContext context, List<Map<String, dynamic>> courses) {
    final c = SrmColors.of(context);
    String v(Map<String, dynamic> m, String k) => m[k]?.toString().trim() ?? '';

    return SrmPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Course Details'),
          const SizedBox(height: 14),
          for (final course in courses) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.page == SrmPalette.cream
                    ? const Color(0xFFF8FAFC)
                    : c.track,
                borderRadius: BorderRadius.circular(SrmRadii.card),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CodePill(v(course, 'courseCode')),
                      const Spacer(),
                      if (v(course, 'slot').isNotEmpty)
                        SoftPill(
                          label:
                              'SLOT ${v(course, 'slot').replaceAll(RegExp(r'-+$'), '')}',
                          background: c.border,
                          foreground: c.text,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    v(course, 'courseTitle'),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: c.text),
                  ),
                  const SizedBox(height: 12),
                  if (v(course, 'facultyName').isNotEmpty)
                    _detailRow(
                      context,
                      FacultyAvatar(
                          facultyName: v(course, 'facultyName'), radius: 12),
                      v(course, 'facultyName')
                          .replaceAll(RegExp(r'\(.*?\)'), '')
                          .trim(),
                    ),
                  if (v(course, 'roomNo').isNotEmpty)
                    _detailRow(
                      context,
                      Icon(LucideIcons.mapPin, size: 14, color: c.muted),
                      v(course, 'roomNo'),
                    ),
                  if (v(course, 'courseType').isNotEmpty ||
                      v(course, 'credit').isNotEmpty)
                    _detailRow(
                      context,
                      Icon(LucideIcons.clock, size: 14, color: c.muted),
                      [
                        if (v(course, 'courseType').isNotEmpty)
                          v(course, 'courseType'),
                        if (v(course, 'credit').isNotEmpty)
                          '${v(course, 'credit')} credits',
                      ].join(' · '),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, Widget lead, String text) {
    final c = SrmColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 26, child: Center(child: lead)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w500, color: c.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// A Day 1–5 selector pill: black when selected, terracotta ring for today.
class _DayPill extends StatelessWidget {
  final int day;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  const _DayPill({
    required this.day,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Day $day${today ? ', today' : ''}',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? c.hero : c.card,
          shape: StadiumBorder(
            side: selected
                ? BorderSide.none
                : today
                    ? const BorderSide(color: SrmPalette.terracotta, width: 2)
                    : BorderSide(color: c.border),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Day $day',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? c.onHero : c.text,
                    ),
                  ),
                  if (today) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: SrmPalette.terracotta,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A class, as the web's pastel timetable cells.
class _ClassCell extends StatelessWidget {
  final TimetableSlotWithTiming slot;
  final ClassTimeInfo info;
  final Map<String, dynamic> course;
  final Color color;

  const _ClassCell({
    required this.slot,
    required this.info,
    required this.course,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final faculty = course['facultyName']?.toString().trim() ?? '';
    final room = course['roomNo']?.toString().trim() ?? '';
    final live = info.state == ClassTimeState.ongoing;
    final next = info.state == ClassTimeState.upcomingNext;
    final done = info.state == ClassTimeState.completed;
    const ink = SrmPalette.ink;

    return Opacity(
      opacity: done ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(SrmRadii.card),
          border: Border.all(
            color: live ? ink : Colors.black.withAlpha(13),
            width: live ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  slot.courseCode.toUpperCase(),
                  style: TextStyle(
                    fontFamily: SrmFonts.mono,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: ink.withAlpha(178),
                  ),
                ),
                const Spacer(),
                if (live)
                  const SoftPill(
                    label: 'LIVE NOW',
                    icon: LucideIcons.radio,
                    background: ink,
                    foreground: Colors.white,
                  )
                else if (next)
                  SoftPill(
                    label: 'UP NEXT · ${info.minutesUntilStart ?? 0} MIN',
                    background: Colors.white.withAlpha(178),
                    foreground: ink,
                  )
                else if (done)
                  const Icon(LucideIcons.check, size: 16, color: ink),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              slot.courseTitle.isNotEmpty ? slot.courseTitle : slot.courseCode,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.3,
                color: ink,
              ),
            ),
            if (faculty.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  FacultyAvatar(facultyName: faculty, radius: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      faculty.replaceAll(RegExp(r'\(.*?\)'), '').trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: ink.withAlpha(204),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.black.withAlpha(13)),
            const SizedBox(height: 10),
            Row(
              children: [
                SoftPill(
                  label: slot.timing,
                  icon: LucideIcons.clock,
                  background: Colors.black.withAlpha(13),
                  foreground: ink,
                ),
                const Spacer(),
                if (room.isNotEmpty) ...[
                  const Icon(LucideIcons.mapPin, size: 13, color: ink),
                  const SizedBox(width: 4),
                  Text(
                    room,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ],
              ],
            ),
            if (live && info.progressFraction != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: info.progressFraction,
                  minHeight: 6,
                  color: ink,
                  backgroundColor: Colors.white.withAlpha(128),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
