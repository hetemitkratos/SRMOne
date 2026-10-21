// lib/features/attendance/attendance_planner_screen.dart
// The attendance planner, laid out like the web app's AttendancePlanner:
// a Reach Target / Plan Holiday switch; Reach Target has a target slider,
// three summary cards and a per-course breakdown; Plan Holiday has a date
// range, four summary cards, an at-risk warning, a day-by-day breakdown and
// each course's impact. The maths lives in attendance_planner_math.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/attendance_planner_math.dart';
import '../../domain/services/calendar_day_resolver.dart';
import '../../domain/services/day_timeline.dart';
import '../../domain/services/timetable_schedule.dart';
import '../shared/cached_data_providers.dart';
import '../shared/ui/srm_ui.dart';

enum _Mode { target, holiday }

class AttendancePlannerScreen extends ConsumerStatefulWidget {
  const AttendancePlannerScreen({super.key});

  @override
  ConsumerState<AttendancePlannerScreen> createState() =>
      _AttendancePlannerScreenState();
}

class _AttendancePlannerScreenState
    extends ConsumerState<AttendancePlannerScreen> {
  _Mode _mode = _Mode.target;
  int _target = 75;
  DateTime? _from;
  DateTime? _to;
  bool _showDays = false;

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(attendanceRecordsProvider).valueOrNull ??
        const <AttendanceCacheData>[];
    final inputs = [
      for (final r in records)
        AttendanceInput(
          courseCode: r.courseCode,
          courseTitle: r.courseTitle,
          hoursConducted: r.hoursConducted,
          hoursAbsent: r.hoursAbsent,
          attendancePct: r.attendancePct,
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Planner')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _modeSwitch(context),
          const SizedBox(height: 16),
          if (inputs.isEmpty)
            const EmptyPanel(
              illustration: AssetPaths.onlineLearning,
              title: 'No attendance data yet',
              message: 'The planner needs your attendance from the Student '
                  'Portal. Pull down on Attendance to refresh.',
            )
          else if (_mode == _Mode.target)
            ..._reachTarget(context, inputs)
          else
            ..._planHoliday(context, inputs),
        ],
      ),
    );
  }

  /// The black track with the two modes (mint when selected), as on the web.
  Widget _modeSwitch(BuildContext context) {
    Widget option(_Mode m, IconData icon, String label) {
      final selected = _mode == m;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: GestureDetector(
            onTap: () => setState(() => _mode = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 46,
              decoration: BoxDecoration(
                color: selected ? SrmPalette.mint : Colors.transparent,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 16,
                      color: selected
                          ? SrmPalette.ink
                          : Colors.white.withAlpha(140)),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: selected
                          ? SrmPalette.ink
                          : Colors.white.withAlpha(140),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: SrmPalette.ink,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        children: [
          option(_Mode.target, LucideIcons.target, 'Reach Target'),
          option(_Mode.holiday, LucideIcons.plane, 'Plan Holiday'),
        ],
      ),
    );
  }

  // ─── Reach Target ──────────────────────────────────────────────────────────

  List<Widget> _reachTarget(
      BuildContext context, List<AttendanceInput> inputs) {
    final results = computeReachTarget(inputs, _target);
    final totalNeeded =
        results.fold<int>(0, (s, r) => s + (r.needed > 0 ? r.needed : 0));
    final totalBunkable = results.fold<int>(0, (s, r) => s + r.bunkable);
    final below = results.where((r) => !r.alreadyAbove).length;

    return [
      _darkCard(
        illustration: AssetPaths.target,
        icon: LucideIcons.target,
        label: 'TARGET ATTENDANCE',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: SrmPalette.mint,
                      inactiveTrackColor: Colors.white.withAlpha(40),
                      thumbColor: SrmPalette.mint,
                      overlayColor: SrmPalette.mint.withAlpha(40),
                    ),
                    child: Slider(
                      value: _target.toDouble(),
                      min: 50,
                      max: 100,
                      divisions: 50,
                      label: '$_target%',
                      onChanged: (v) => setState(() => _target = v.round()),
                    ),
                  ),
                ),
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: '$_target',
                    style: const TextStyle(
                      fontFamily: SrmFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 40,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                  TextSpan(
                    text: '%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Colors.white.withAlpha(100),
                    ),
                  ),
                ])),
              ],
            ),
            Text(
              'Slide to set your attendance goal',
              style:
                  TextStyle(fontSize: 12, color: Colors.white.withAlpha(128)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      PastelStatCard(
        label: 'Classes to Attend',
        value: '$totalNeeded',
        caption: 'to reach $_target%',
        icon: LucideIcons.target,
        color: SrmPalette.terracotta,
        onDark: true,
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PastelStatCard(
                label: 'Can Bunk',
                value: '$totalBunkable',
                caption: 'classes to skip',
                icon: LucideIcons.circleCheck,
                color: SrmPalette.mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PastelStatCard(
                label: 'Below Target',
                value: '$below',
                caption: 'courses need work',
                icon: LucideIcons.trendingDown,
                color: SrmPalette.lavender,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SrmPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Course Breakdown', size: 20),
            const SizedBox(height: 12),
            for (final r in results) ...[
              _targetRow(context, r),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _targetRow(BuildContext context, ReachTargetResult r) {
    final c = SrmColors.of(context);
    final (String label, Color bg, Color fg) = r.isUnreachable100
        ? ('Can\'t reach 100% (missed ${r.absent} hr)', _redBg, _redFg)
        : r.needed > 0
            ? (
                'Attend ${r.needed} class${r.needed == 1 ? '' : 'es'}',
                _redBg,
                _redFg
              )
            : r.bunkable > 0
                ? ('Can bunk ${r.bunkable}', _greenBg, _greenFg)
                : ('On track', _amberBg, _amberFg);
    return _subjectBox(
      context,
      code: r.courseCode,
      title: r.courseTitle,
      badge: _badge(label, bg, fg),
      footer: Text.rich(
        TextSpan(children: [
          TextSpan(
            text: 'Now ${r.pct.toStringAsFixed(1)}%',
            style: TextStyle(color: c.muted),
          ),
          if (r.needed > 0) ...[
            TextSpan(text: '  →  ', style: TextStyle(color: c.faint)),
            TextSpan(
              text: 'then ${r.newPct.toStringAsFixed(1)}%',
              style: const TextStyle(color: SrmPalette.mintText),
            ),
          ],
        ]),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ─── Plan Holiday ──────────────────────────────────────────────────────────

  List<Widget> _planHoliday(
      BuildContext context, List<AttendanceInput> inputs) {
    final c = SrmColors.of(context);
    final courses = ref.watch(timetableCoursesProvider);
    final calendarMap = ref.watch(calendarMapProvider(currentSemester()));
    final fmt = DateFormat('d MMM');

    final picker = _darkCard(
      illustration: AssetPaths.travelPlans,
      icon: LucideIcons.plane,
      label: 'PLAN YOUR HOLIDAY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _dateField('From', _from, () => _pick(true))),
              const SizedBox(width: 10),
              Expanded(child: _dateField('To', _to, () => _pick(false))),
            ],
          ),
          if (courses.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Timetable not loaded, so Mon–Fri are taken as Day 1–5.',
              style: TextStyle(
                  fontSize: 11, color: SrmPalette.amber.withAlpha(220)),
            ),
          ],
        ],
      ),
    );

    if (_from == null || _to == null) {
      return [
        picker,
        const SizedBox(height: 16),
        const EmptyPanel(
          illustration: AssetPaths.aDayOff,
          title: 'Plan your holiday',
          message: 'Pick the days you plan to miss. The planner uses your '
              'timetable and the academic calendar\'s day orders to count '
              'the classes you would miss in each course.',
        ),
      ];
    }

    // Day by day: which day order each date is and how many classes it has.
    final days = <({DateTime date, String label, bool working, int classes})>[];
    for (var d = _from!;
        !d.isAfter(_to!);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final s = CalendarDayResolver.getDayStatus(calendarMap, d);
      final working = calendarMap.isEmpty ? d.weekday <= 5 : s.isWorkingDay;
      final label = calendarMap.isEmpty
          ? (d.weekday <= 5 ? 'Day ${d.weekday}' : 'Weekend')
          : s.isWorkingDay
              ? s.dayLabel
              : s.isHoliday
                  ? 'Holiday'
                  : s.isWeekend
                      ? 'Weekend'
                      : 'No classes';
      days.add((
        date: d,
        label: label,
        working: working,
        classes:
            working ? TimetableSchedule.slotsForDay(courses, label).length : 0,
      ));
    }

    final results = computePlanHoliday(
      fromDate: _from!,
      toDate: _to!,
      records: inputs,
      timetableSlots: timetableSlotsFromCourses(courses),
      calendarResolver: calendarMap.isEmpty
          ? null
          : (dt) {
              final s = CalendarDayResolver.getDayStatus(calendarMap, dt);
              return ResolvedDayStatus(
                isWorking: s.isWorkingDay,
                dayLabel: s.isWorkingDay ? s.dayLabel : null,
              );
            },
    );
    final hit = results.where((r) => r.missed > 0).toList()
      ..sort((a, b) => b.drop.compareTo(a.drop));
    final totalMissed = hit.fold<int>(0, (s, r) => s + r.missed);

    if (totalMissed == 0) {
      return [
        picker,
        const SizedBox(height: 16),
        EmptyPanel(
          illustration: AssetPaths.vacationSelfie,
          title: 'No classes missed!',
          message: '${fmt.format(_from!)} – ${fmt.format(_to!)} has no '
              'working days with classes. You\'re clear to take it off.',
        ),
      ];
    }

    final summary = computeAttendanceSummary(inputs);
    final conductedAll = inputs.fold<int>(0, (s, r) => s + r.hoursConducted);
    final presentAll = inputs.fold<int>(0, (s, r) => s + r.hoursPresent);
    final projected = conductedAll + totalMissed > 0
        ? presentAll / (conductedAll + totalMissed) * 100
        : 0.0;
    final atRisk = hit.where((r) => r.willDropBelow75).length;
    final workingDays = days.where((d) => d.working).length;

    return [
      picker,
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PastelStatCard(
                label: 'Days Off',
                value: '$workingDays',
                caption: 'working days',
                icon: LucideIcons.calendar,
                color: SrmPalette.mint,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PastelStatCard(
                label: 'Classes Missed',
                value: '$totalMissed',
                caption: 'hours',
                icon: LucideIcons.trendingDown,
                color: SrmPalette.lavender,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: PastelStatCard(
                label: 'Overall',
                value: projected.toStringAsFixed(1),
                suffix: '%',
                caption:
                    'now ${summary.weightedOverallPct.toStringAsFixed(1)}%, by hours',
                icon: LucideIcons.trendingUp,
                color: SrmPalette.beige,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PastelStatCard(
                label: 'At Risk',
                value: '$atRisk',
                caption: 'drop below 75%',
                icon: LucideIcons.triangleAlert,
                color: SrmPalette.terracotta,
                onDark: true,
              ),
            ),
          ],
        ),
      ),
      if (atRisk > 0) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SrmPalette.terracotta.withAlpha(26),
            borderRadius: BorderRadius.circular(SrmRadii.card),
            border: Border.all(color: SrmPalette.terracotta.withAlpha(77)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.triangleAlert,
                  size: 18, color: SrmPalette.terracottaText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$atRisk course${atRisk == 1 ? '' : 's'} will drop below 75% '
                  'if you take this holiday. See how many classes you need '
                  'afterwards below.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: SrmPalette.terracottaText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      SrmPanel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _showDays = !_showDays),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 18, color: c.faint),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: SectionTitle('Day-by-day Breakdown', size: 18)),
                    Icon(
                        _showDays
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 18,
                        color: c.faint),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              alignment: Alignment.topCenter,
              child: !_showDays
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final d in days)
                            Container(
                              width: 92,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 6),
                              decoration: BoxDecoration(
                                color: d.working
                                    ? SrmPalette.terracotta.withAlpha(26)
                                    : c.track,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Text(fmt.format(d.date),
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: c.faint)),
                                  const SizedBox(height: 2),
                                  Text(d.label,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: d.working
                                              ? SrmPalette.terracottaText
                                              : c.faint)),
                                  if (d.working)
                                    Text(
                                        '${d.classes} class${d.classes == 1 ? '' : 'es'}',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: SrmPalette.terracottaText)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SrmPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Course Impact', size: 20),
            const SizedBox(height: 12),
            for (final r in hit) ...[
              _impactRow(context, r),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            Text(
              'Missed classes come from your timetable and the academic '
              'calendar\'s day orders; holidays and weekends in the range '
              'are left out.',
              style: TextStyle(fontSize: 11, color: c.faint, height: 1.4),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _impactRow(BuildContext context, PlanHolidayResult r) {
    final c = SrmColors.of(context);
    Widget stat(String label, String value, Color color) => Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: c.faint)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: color)),
          ],
        );
    return _subjectBox(
      context,
      code: r.courseCode,
      title: r.courseTitle,
      badge: r.recoveryNeeded > 0
          ? _badge('Need ${r.recoveryNeeded}', _redBg, _redFg)
          : _badge('Still safe', _greenBg, _greenFg),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Missing ', style: TextStyle(color: c.muted)),
                TextSpan(
                  text: '${r.missed} class${r.missed == 1 ? '' : 'es'}',
                  style: const TextStyle(color: SrmPalette.lavenderText),
                ),
              ]),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              stat('NOW', '${r.currentPct.toStringAsFixed(1)}%',
                  r.currentPct < 75 ? c.bad : c.text),
              Icon(LucideIcons.arrowRight, size: 14, color: c.faint),
              stat('AFTER', '${r.newPct.toStringAsFixed(1)}%',
                  r.newPct < 75 ? c.bad : c.text),
              stat('DROP', '-${r.drop.toStringAsFixed(1)}%',
                  SrmPalette.terracottaText),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(bool from) async {
    final today = DateTime.now();
    final first =
        from ? DateTime(today.year, today.month, today.day) : (_from ?? today);
    final initial = from ? (_from ?? first) : (_to ?? _from ?? first);
    final picked = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: DateTime(today.year + 1, today.month, today.day),
      initialDate: initial.isBefore(first) ? first : initial,
      helpText: from ? 'First day off' : 'Last day off',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_to != null && _to!.isBefore(picked)) _to = picked;
      } else {
        _to = picked;
      }
    });
  }

  // ─── Shared pieces ─────────────────────────────────────────────────────────

  Widget _darkCard({
    required String illustration,
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: SrmColors.of(context).hero,
        borderRadius: BorderRadius.circular(SrmRadii.panel),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: 8,
            width: 96,
            height: 72,
            child: Opacity(
              opacity: 0.85,
              child: SvgPicture.asset(illustration,
                  fit: BoxFit.contain, excludeFromSemantics: true),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: SrmPalette.mint),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white.withAlpha(204),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.white.withAlpha(128),
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white.withAlpha(26),
          shape: StadiumBorder(
              side: BorderSide(color: Colors.white.withAlpha(51))),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(LucideIcons.calendar,
                      size: 15, color: Colors.white.withAlpha(178)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value == null
                          ? 'Pick a date'
                          : DateFormat('EEE, d MMM').format(value),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: value == null
                            ? Colors.white.withAlpha(128)
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _subjectBox(
    BuildContext context, {
    required String code,
    required String title,
    required Widget badge,
    required Widget footer,
  }) {
    final c = SrmColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.page == SrmPalette.cream ? const Color(0xFFF8FAFC) : c.track,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CodePill(code),
              const Spacer(),
              badge,
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tidyTitle(title.isNotEmpty ? title : code),
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: c.text),
          ),
          const SizedBox(height: 4),
          footer,
        ],
      ),
    );
  }

  Widget _badge(String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );

  // The web's red/green/amber badge colours (Tailwind 100/700).
  static const _redBg = Color(0xFFFEE2E2);
  static const _redFg = Color(0xFFB91C1C);
  static const _greenBg = Color(0xFFD1FAE5);
  static const _greenFg = Color(0xFF047857);
  static const _amberBg = Color(0xFFFEF3C7);
  static const _amberFg = Color(0xFFB45309);
}
