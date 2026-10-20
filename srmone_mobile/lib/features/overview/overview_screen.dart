// lib/features/overview/overview_screen.dart
// Dashboard Overview screen with Monday–Friday day-order strip,
// clock-based Live/Upcoming class detector, quick attendance stats, and today's schedule.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../../domain/services/attendance_planner_math.dart';
import '../../domain/services/calendar_day_resolver.dart';
import '../../domain/services/current_class_detector.dart';
import '../../domain/services/timetable_schedule.dart';
import '../../main.dart';
import '../auth/auth_controller.dart';
import '../faculty/faculty_avatar.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';
    final db = ref.watch(appDatabaseProvider);

    if (email.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view overview.')),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(appRefresherProvider).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // Top App Bar
            SliverAppBar(
              floating: true,
              pinned: true,
              title: Consumer(
                builder: (context, ref, _) {
                  final snapshot = ref.watch(studentProfileProvider);
                  final name = snapshot.valueOrNull?.name ?? 'Student';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hi, ${name.split(' ').first}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        snapshot.valueOrNull?.regNumber ?? email,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Consumer(
                  builder: (context, ref, _) {
                    final calMap =
                        ref.watch(calendarMapProvider(currentSemester()));
                    final now = DateTime.now();
                    final todayStatus =
                        CalendarDayResolver.getDayStatus(calMap, now);

                    return Consumer(
                      builder: (context, ref, _) {
                        final courses = ref.watch(timetableCoursesProvider);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Week Day-Order Strip
                            _buildWeekDayStrip(theme, calMap, now),
                            const SizedBox(height: 20),

                            // 2. Live Now / Up Next Hero Card
                            _buildLiveHeroCard(
                              context,
                              theme,
                              todayStatus,
                              courses,
                              now,
                            ),
                            const SizedBox(height: 20),

                            // 3. Quick Attendance Stat Card
                            _buildQuickAttendanceCard(
                              context,
                              theme,
                              db,
                              email,
                            ),
                            const SizedBox(height: 24),

                            // 4. Today's Classes Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  todayStatus.dayLabel.isNotEmpty
                                      ? "TODAY'S SCHEDULE (${todayStatus.dayLabel})"
                                      : "TODAY'S SCHEDULE",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                    color: Colors.grey,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => context.go('/timetable'),
                                  child: const Text('View Full'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // 5. Today's Classes List
                            _buildTodayScheduleList(
                              theme,
                              todayStatus,
                              courses,
                              now,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 1. Week Day-Order Strip (Mon–Fri) ────────────────────────────────────────

  Widget _buildWeekDayStrip(
    ThemeData theme,
    Map<String, CalendarEntry> calMap,
    DateTime now,
  ) {
    // Determine the Monday of the current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekdays = List.generate(5, (i) => monday.add(Duration(days: i)));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: weekdays.map((date) {
            final isToday = date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
            final status = CalendarDayResolver.getDayStatus(calMap, date);
            final dayName =
                ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'][date.weekday - 1];

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isToday ? const Color(0xFF2D6A4F) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isToday ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isToday ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (status.isWorkingDay)
                    Text(
                      'D${status.dayOrderNum}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isToday
                            ? const Color(0xFFBDE3D5)
                            : const Color(0xFF2D6A4F),
                      ),
                    )
                  else if (status.isHoliday)
                    const Text(
                      'HOL',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    )
                  else
                    const Text(
                      '-',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── 2. Live Now / Up Next Hero Card ─────────────────────────────────────────

  Widget _buildLiveHeroCard(
    BuildContext context,
    ThemeData theme,
    DayStatus todayStatus,
    List<Map<String, dynamic>> courses,
    DateTime now,
  ) {
    if (todayStatus.isHoliday ||
        todayStatus.isWeekend ||
        !todayStatus.isWorkingDay) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.dividerColor.withAlpha(40)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SvgPicture.asset(AssetPaths.chilling, height: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todayStatus.isHoliday
                          ? 'Holiday Today!'
                          : todayStatus.isWeekend
                              ? 'Weekend!'
                              : 'No day order yet',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      todayStatus.event.isNotEmpty
                          ? todayStatus.event
                          : todayStatus.type == DayStatusType.unknown
                              ? "Today's day order isn't in the academic calendar yet."
                              : 'No classes scheduled today. Relax!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final slots = TimetableSchedule.slotsForDay(courses, todayStatus.dayLabel);
    final classified = CurrentClassDetector.classify(
      slots,
      todayStatus.dayLabel,
      now,
    );

    final ongoing =
        classified.where((c) => c.$2.state == ClassTimeState.ongoing).toList();
    final upcoming = classified
        .where((c) => c.$2.state == ClassTimeState.upcomingNext)
        .toList();

    if (ongoing.isNotEmpty) {
      final (slot, info) = ongoing.first;
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2D6A4F), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.radio, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'LIVE NOW',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    slot.timing,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                slot.courseTitle.isNotEmpty
                    ? slot.courseTitle
                    : slot.courseCode,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                slot.courseCode,
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              if (info.progressFraction != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: info.progressFraction,
                    color: const Color(0xFF2D6A4F),
                    backgroundColor: theme.dividerColor.withAlpha(40),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (upcoming.isNotEmpty) {
      final (slot, info) = upcoming.first;
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.orangeAccent),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.orange.withAlpha(30),
                child: const Icon(
                  LucideIcons.clock,
                  color: Colors.orangeAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UP NEXT in ${info.minutesUntilStart ?? 0}m',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      slot.courseTitle.isNotEmpty
                          ? slot.courseTitle
                          : slot.courseCode,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // All classes finished
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SvgPicture.asset(AssetPaths.coffeeTime, height: 50),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Classes Done!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'No more scheduled lectures today.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. Quick Attendance Stat Card ───────────────────────────────────────────

  Widget _buildQuickAttendanceCard(
    BuildContext context,
    ThemeData theme,
    AppDatabase db,
    String email,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final snapshot = ref.watch(attendanceRecordsProvider);
        final records = snapshot.valueOrNull ?? [];
        if (records.isEmpty) return const SizedBox.shrink();

        final inputs = records
            .map((r) => AttendanceInput(
                  courseCode: r.courseCode,
                  courseTitle: r.courseTitle,
                  hoursConducted: r.hoursConducted,
                  hoursAbsent: r.hoursAbsent,
                  attendancePct: r.attendancePct,
                ))
            .toList();

        final summary = computeAttendanceSummary(inputs);

        return GestureDetector(
          onTap: () => context.go('/attendance'),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.dividerColor.withAlpha(40)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: const Color(0xFF2D6A4F).withAlpha(30),
                        child: Text(
                          '${summary.unweightedMeanPct.toInt()}%',
                          style: const TextStyle(
                            color: Color(0xFF2D6A4F),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overall Attendance',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${summary.above75} safe • ${summary.below75} below 75%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Icon(LucideIcons.chevronRight,
                      size: 18, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── 4. Today's Classes List ─────────────────────────────────────────────────

  Widget _buildTodayScheduleList(
    ThemeData theme,
    DayStatus todayStatus,
    List<Map<String, dynamic>> courses,
    DateTime now,
  ) {
    if (!todayStatus.isWorkingDay) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text(
          'No timetable slots for today.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final slots = TimetableSchedule.slotsForDay(courses, todayStatus.dayLabel);
    if (slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const Text(
          'No classes mapped to this Day Order.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: slots.map((s) {
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor.withAlpha(30)),
          ),
          child: ListTile(
            leading: FacultyAvatar(
              facultyName:
                  s.courseTitle.isNotEmpty ? s.courseTitle : s.courseCode,
              radius: 16,
            ),
            title: Text(
              s.courseTitle.isNotEmpty ? s.courseTitle : s.courseCode,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${s.courseCode} • ${s.timing}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        );
      }).toList(),
    );
  }
}
