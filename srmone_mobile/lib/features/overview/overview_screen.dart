// lib/features/overview/overview_screen.dart
// Home, laid out like the web app's Overview page: the "Welcome back" hero,
// mint/lavender stat cards, the live/up-next class, a beige schedule panel
// whose Mon–Fri strip picks the day shown, and compact attendance bars.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/attendance_planner_math.dart';
import '../../domain/services/calendar_day_resolver.dart';
import '../../domain/services/current_class_detector.dart';
import '../../domain/services/day_timeline.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import '../../domain/services/timetable_schedule.dart';
import '../auth/auth_controller.dart';
import '../faculty/faculty_avatar.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';
import '../shared/ui/srm_ui.dart';

class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  /// The weekday (1 = Mon … 5 = Fri) picked in the schedule strip, or null
  /// for today.
  int? _pickedWeekday;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';

    if (email.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view overview.')),
      );
    }

    final profile = ref.watch(studentProfileProvider).valueOrNull;
    final courses = ref.watch(timetableCoursesProvider);
    final records = ref.watch(attendanceRecordsProvider).valueOrNull ?? [];
    final calMap = ref.watch(calendarMapProvider(currentSemester()));
    final now = DateTime.now();
    final todayStatus = CalendarDayResolver.getDayStatus(calMap, now);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(appRefresherProvider).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: staggeredEntrance(context, [
            _hero(context, profile),
            const SizedBox(height: 16),
            const SyncSectionNotice(
              sections: [SyncSection.academia, SyncSection.attendance],
              what: 'your data',
            ),
            _statsRow(courses, records),
            const SizedBox(height: 16),
            _LiveClassCard(
                todayStatus: todayStatus, courses: courses, now: now),
            const SizedBox(height: 16),
            _schedulePanel(context, calMap, todayStatus, courses, now),
            const SizedBox(height: 16),
            if (records.isNotEmpty) _attendancePanel(context, records),
          ]),
        ),
      ),
    );
  }

  // ─── Hero ────────────────────────────────────────────────────────────────

  Widget _hero(BuildContext context, StudentProfile? profile) {
    final first = (profile?.name ?? '').trim().split(RegExp(r'\s+')).first;
    final details = [
      if ((profile?.branch ?? '').isNotEmpty) profile!.branch,
      if ((profile?.batch ?? '').isNotEmpty) 'Batch ${profile!.batch}',
    ].join(' • ');
    return HeroBanner(
      eyebrow: 'Welcome back,',
      title: first.isEmpty ? 'Student' : _titleCase(first),
      subtitle: details,
      illustration: AssetPaths.learning,
      action: HeroPillButton(
        label: 'View Timetable',
        icon: LucideIcons.calendarDays,
        onPressed: () => context.go('/timetable'),
      ),
    );
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  Widget _statsRow(
      List<Map<String, dynamic>> courses, List<AttendanceCacheData> records) {
    final summary = computeAttendanceSummary(_inputs(records));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PastelStatCard(
              label: 'Total Courses',
              value: '${courses.length}',
              caption: 'Enrolled',
              icon: LucideIcons.arrowUpRight,
              color: SrmPalette.mint,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PastelStatCard(
              label: 'Attendance',
              value: records.isEmpty
                  ? '—'
                  : summary.unweightedMeanPct.toStringAsFixed(1),
              suffix: records.isEmpty ? null : '%',
              caption: records.isEmpty
                  ? 'Not loaded yet'
                  : '${summary.below75} below 75%',
              color: SrmPalette.lavender,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Schedule panel ──────────────────────────────────────────────────────

  Widget _schedulePanel(
    BuildContext context,
    Map<String, CalendarEntry> calMap,
    DayStatus todayStatus,
    List<Map<String, dynamic>> courses,
    DateTime now,
  ) {
    final c = SrmColors.of(context);
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final weekdays = List.generate(5, (i) => monday.add(Duration(days: i)));
    final todayWeekday = now.weekday <= 5 ? now.weekday : null;
    final picked = _pickedWeekday ?? todayWeekday;
    final pickedDate = picked == null ? null : weekdays[picked - 1];
    final pickedStatus = pickedDate == null
        ? null
        : CalendarDayResolver.getDayStatus(calMap, pickedDate);
    final isToday = picked != null && picked == todayWeekday;

    final todayLabel = todayStatus.isHoliday
        ? 'Holiday'
        : todayStatus.isWeekend
            ? 'Weekend'
            : todayStatus.dayLabel.isNotEmpty
                ? todayStatus.dayLabel
                : '—';

    return SrmPanel(
      color: SrmPalette.beige.withAlpha(c.page == SrmPalette.cream ? 102 : 40),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            isToday ? "Today's Schedule" : 'Schedule',
            trailing: SoftPill(
              label: 'Today: $todayLabel',
              background: SrmPalette.terracotta.withAlpha(26),
              foreground: SrmPalette.terracottaText,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final date in weekdays)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _DayChip(
                      date: date,
                      status: CalendarDayResolver.getDayStatus(calMap, date),
                      selected: date.weekday == picked,
                      today: date.weekday == todayWeekday,
                      onTap: () =>
                          setState(() => _pickedWeekday = date.weekday),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _scheduleBody(context, pickedStatus, courses, now, isToday),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => context.go('/timetable'),
              icon: const Icon(LucideIcons.arrowUpRight, size: 16),
              label: const Text('Full timetable'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scheduleBody(
    BuildContext context,
    DayStatus? status,
    List<Map<String, dynamic>> courses,
    DateTime now,
    bool isToday,
  ) {
    if (status == null) {
      return _scheduleNote(
        context,
        AssetPaths.chilling,
        "It's the weekend!",
        'Pick a day above to preview its classes.',
      );
    }
    if (status.isHoliday) {
      return _scheduleNote(
        context,
        AssetPaths.vacationSelfie,
        status.event.isNotEmpty ? status.event : "It's a holiday!",
        'No classes this day.',
      );
    }
    if (!status.isWorkingDay) {
      return _scheduleNote(
        context,
        AssetPaths.calendar,
        'No day order yet',
        "This day isn't in the academic calendar yet.",
      );
    }

    final slots = TimetableSchedule.slotsForDay(courses, status.dayLabel);
    if (slots.isEmpty) {
      return _scheduleNote(
        context,
        AssetPaths.coffeeTime,
        'No classes scheduled for ${status.dayLabel}',
        'Enjoy your free time!',
      );
    }

    final byCode = {
      for (final c in courses) c['courseCode']?.toString() ?? '': c,
    };
    final states = isToday
        ? {
            for (final (s, info)
                in CurrentClassDetector.classify(slots, status.dayLabel, now))
              s: info.state,
          }
        : const <TimetableSlotWithTiming, ClassTimeState>{};

    return Column(
      children: [
        for (final s in slots)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ClassCard(
              slot: s,
              course: byCode[s.courseCode] ?? const {},
              state: states[s],
            ),
          ),
      ],
    );
  }

  Widget _scheduleNote(
      BuildContext context, String art, String title, String message) {
    final c = SrmColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: c.card.withAlpha(128),
        borderRadius: BorderRadius.circular(SrmRadii.card),
      ),
      child: Column(
        children: [
          SvgPicture.asset(art, height: 96, excludeFromSemantics: true),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16, color: c.text),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.muted),
          ),
        ],
      ),
    );
  }

  // ─── Attendance panel ────────────────────────────────────────────────────

  Widget _attendancePanel(
      BuildContext context, List<AttendanceCacheData> records) {
    final c = SrmColors.of(context);
    final sorted = [...records]
      ..sort((a, b) => a.attendancePct.compareTo(b.attendancePct));
    return SrmPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Attendance',
            trailing: RoundIconButton(
              icon: LucideIcons.arrowUpRight,
              tooltip: 'Open attendance',
              onPressed: () => context.go('/attendance'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lowest first',
            style: TextStyle(fontSize: 12, color: c.muted),
          ),
          const SizedBox(height: 14),
          for (final r in sorted.take(5)) ...[
            Row(
              children: [
                FacultyAvatar(
                  facultyName:
                      r.facultyName.isNotEmpty ? r.facultyName : r.courseTitle,
                  showsProfile: r.facultyName.isNotEmpty,
                  radius: 12,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tidyTitle(r.courseTitle.isNotEmpty
                        ? r.courseTitle
                        : r.courseCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${r.attendancePct.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SrmProgressBar(
              value: r.attendancePct / 100,
              color: attendanceBarColor(r.attendancePct),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  static List<AttendanceInput> _inputs(List<AttendanceCacheData> records) => [
        for (final r in records)
          AttendanceInput(
            courseCode: r.courseCode,
            courseTitle: r.courseTitle,
            hoursConducted: r.hoursConducted,
            hoursAbsent: r.hoursAbsent,
            attendancePct: r.attendancePct,
          ),
      ];

  static String _titleCase(String w) =>
      w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();
}

// ─── Week strip chip ─────────────────────────────────────────────────────────

/// One weekday in the schedule strip: black when picked, a terracotta ring
/// for today, as the web's day pills.
class _DayChip extends StatelessWidget {
  final DateTime date;
  final DayStatus status;
  final bool selected;
  final bool today;
  final VoidCallback onTap;

  const _DayChip({
    required this.date,
    required this.status,
    required this.selected,
    required this.today,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final fg = selected ? c.onHero : c.text;
    final sub = status.isWorkingDay
        ? 'D${status.dayOrderNum}'
        : status.isHoliday
            ? 'HOL'
            : '–';
    final subColor = selected
        ? c.onHero.withAlpha(178)
        : status.isHoliday
            ? SrmPalette.terracottaText
            : c.muted;
    final name = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][date.weekday - 1];

    return Semantics(
      button: true,
      selected: selected,
      label: '$name ${date.day}, '
          '${status.isWorkingDay ? 'day order ${status.dayOrderNum}' : status.isHoliday ? 'holiday' : 'no day order'}'
          '${today ? ', today' : ''}',
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
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected ? c.onHero.withAlpha(178) : c.muted)),
                  const SizedBox(height: 2),
                  Text('${date.day}',
                      style: TextStyle(
                          fontFamily: SrmFonts.display,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: fg)),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: subColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Class card ──────────────────────────────────────────────────────────────

/// A class in the schedule panel, like the web's white schedule cards.
class _ClassCard extends StatelessWidget {
  final TimetableSlotWithTiming slot;
  final Map<String, dynamic> course;
  final ClassTimeState? state;

  const _ClassCard({required this.slot, required this.course, this.state});

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final faculty = course['facultyName']?.toString().trim() ?? '';
    final room = course['roomNo']?.toString().trim() ?? '';
    final done = state == ClassTimeState.completed;
    final live = state == ClassTimeState.ongoing;

    return Opacity(
      opacity: done ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(SrmRadii.card),
          border: live
              ? Border.all(color: c.text, width: 1.5)
              : Border.all(color: c.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CodePill(slot.courseCode),
                if (live) ...[
                  const SizedBox(width: 6),
                  const SoftPill(
                    label: 'LIVE',
                    background: SrmPalette.mint,
                    foreground: SrmPalette.ink,
                  ),
                ],
                const Spacer(),
                Text(
                  formatTiming(slot.timing),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: c.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              tidyTitle(slot.courseTitle.isNotEmpty
                  ? slot.courseTitle
                  : slot.courseCode),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                height: 1.3,
                color: c.text,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (faculty.isNotEmpty) ...[
                  FacultyAvatar(facultyName: faculty, radius: 11),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _cleanName(faculty),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.muted,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                if (room.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(LucideIcons.mapPin, size: 14, color: c.muted),
                  const SizedBox(width: 3),
                  Text(
                    room,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.muted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Dr. Jane Doe (103528)" → "Dr. Jane Doe", as the web's `cleanName`.
String _cleanName(String name) =>
    name.replaceAll(RegExp(r'\(.*?\)'), '').trim();

// ─── Live / up-next card ─────────────────────────────────────────────────────

/// What is on now or next today; nothing on days without classes.
class _LiveClassCard extends StatelessWidget {
  final DayStatus todayStatus;
  final List<Map<String, dynamic>> courses;
  final DateTime now;

  const _LiveClassCard({
    required this.todayStatus,
    required this.courses,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    if (!todayStatus.isWorkingDay) return const SizedBox.shrink();
    final slots = TimetableSchedule.slotsForDay(courses, todayStatus.dayLabel);
    if (slots.isEmpty) return const SizedBox.shrink();

    final classified =
        CurrentClassDetector.classify(slots, todayStatus.dayLabel, now);
    final ongoing =
        classified.where((x) => x.$2.state == ClassTimeState.ongoing);
    final upcoming =
        classified.where((x) => x.$2.state == ClassTimeState.upcomingNext);
    final c = SrmColors.of(context);

    if (ongoing.isEmpty && upcoming.isEmpty) {
      return SrmPanel(
        radius: SrmRadii.card,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SvgPicture.asset(AssetPaths.coffeeTime,
                height: 48, excludeFromSemantics: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All classes done!',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: c.text)),
                  const SizedBox(height: 2),
                  Text('No more lectures today.',
                      style: TextStyle(fontSize: 12, color: c.muted)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isLive = ongoing.isNotEmpty;
    final (slot, info) = isLive ? ongoing.first : upcoming.first;
    final label = isLive
        ? 'LIVE NOW'
        : 'NEXT ${startsIn(info.minutesUntilStart ?? 0, info.startMinutes).toUpperCase()}';

    return SrmPanel(
      color: isLive ? SrmPalette.mint : c.card,
      radius: SrmRadii.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftPill(
                label: label,
                icon: isLive ? LucideIcons.radio : LucideIcons.clock,
                background: SrmPalette.ink,
                foreground: Colors.white,
              ),
              const Spacer(),
              Text(
                formatTiming(slot.timing),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isLive ? SrmPalette.ink : c.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tidyTitle(slot.courseTitle.isNotEmpty
                ? slot.courseTitle
                : slot.courseCode),
            style: TextStyle(
              fontFamily: SrmFonts.display,
              fontWeight: FontWeight.w700,
              fontSize: 19,
              height: 1.2,
              color: isLive ? SrmPalette.ink : c.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slot.courseCode,
            style: TextStyle(
              fontFamily: SrmFonts.mono,
              fontSize: 12,
              color: isLive ? SrmPalette.ink.withAlpha(178) : c.muted,
            ),
          ),
          if (isLive && info.progressFraction != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: info.progressFraction,
                minHeight: 8,
                color: SrmPalette.ink,
                backgroundColor: Colors.white.withAlpha(128),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
