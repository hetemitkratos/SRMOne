// lib/features/timetable/timetable_screen.dart
// Timetable screen with swipeable Day 1–5 views, live/upcoming class highlights,
// calendar day order sync, and one-tap PNG poster export.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../../domain/services/calendar_day_resolver.dart';
import '../../domain/services/current_class_detector.dart';
import '../../main.dart';
import '../auth/auth_controller.dart';
import '../faculty/faculty_avatar.dart';
import 'widgets/exportable_timetable_poster.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _todayDayOrder = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';
    final db = ref.watch(appDatabaseProvider);

    if (email.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view timetable.')),
      );
    }

    return StreamBuilder<TimetableCacheData?>(
      stream: db.watchTimetable(email),
      builder: (context, timetableSnap) {
        final timetable = timetableSnap.data;
        final rawCourses = _parseCourses(timetable?.coursesJson);

        return StreamBuilder<CalendarCacheData?>(
          stream: db.watchCalendar(email, 'odd'),
          builder: (context, calendarSnap) {
            final calendar = calendarSnap.data;
            final calendarMap = _buildCalendarMap(calendar?.monthsJson);
            final todayStatus = CalendarDayResolver.getDayStatus(
              calendarMap,
              DateTime.now(),
            );

            if (todayStatus.dayOrderNum != null &&
                todayStatus.dayOrderNum! >= 1 &&
                todayStatus.dayOrderNum! <= 5) {
              _todayDayOrder = todayStatus.dayOrderNum!;
            }

            final dayScheduleMap = _buildDaySchedule(rawCourses);

            return Scaffold(
              appBar: AppBar(
                title: const Text('Timetable'),
                actions: [
                  IconButton(
                    icon: const Icon(LucideIcons.share2),
                    tooltip: 'Export Timetable Poster',
                    onPressed: () async {
                      final profile = await db.getStudentProfile(email);
                      if (context.mounted) {
                        await ExportableTimetablePoster.exportAndShare(
                          context,
                          studentName: profile?.name ?? 'Student',
                          regNumber: profile?.regNumber ?? '',
                          batch: timetable?.batch ?? '1',
                          schedule: dayScheduleMap,
                        );
                      }
                    },
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  tabs: List.generate(5, (index) {
                    final dayNum = index + 1;
                    final isToday =
                        dayNum == _todayDayOrder && todayStatus.isWorkingDay;

                    return Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Day $dayNum'),
                          if (isToday) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2D6A4F),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ),
              ),
              body: RefreshIndicator(
                onRefresh: () async {
                  final orchestrator =
                      ref.read(sessionSyncOrchestratorProvider);
                  await orchestrator.syncAttendance(forceFreshLogin: true);
                },
                child: rawCourses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SvgPicture.asset(
                              AssetPaths.studying,
                              height: 140,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No timetable data found.',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pull down to refresh from portal',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: List.generate(5, (index) {
                          final dayLabel = 'Day ${index + 1}';
                          return _buildDayView(
                            theme,
                            dayLabel,
                            rawCourses,
                            dayLabel == todayStatus.dayLabel,
                          );
                        }),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDayView(
    ThemeData theme,
    String dayLabel,
    List<Map<String, dynamic>> courses,
    bool isToday,
  ) {
    final slotsWithTiming = <TimetableSlotWithTiming>[];

    for (final c in courses) {
      final code =
          c['course_code']?.toString() ?? c['courseCode']?.toString() ?? '';
      final title =
          c['course_title']?.toString() ?? c['courseTitle']?.toString() ?? '';
      final slotStr = c['slot']?.toString() ?? '';

      final matches =
          RegExp(r'Day\s*([1-5])', caseSensitive: false).allMatches(slotStr);
      for (final m in matches) {
        if ('Day ${m.group(1)}' == dayLabel) {
          slotsWithTiming.add(
            TimetableSlotWithTiming(
              courseCode: code,
              courseTitle: title,
              timing: _timingForSlot(slotStr),
              hourIndex: slotsWithTiming.length + 1,
              day: dayLabel,
            ),
          );
        }
      }
    }

    if (slotsWithTiming.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(AssetPaths.aDayOff, height: 120),
            const SizedBox(height: 16),
            Text(
              'No classes scheduled for $dayLabel',
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final classified = isToday
        ? CurrentClassDetector.classify(
            slotsWithTiming,
            dayLabel,
            DateTime.now(),
          )
        : slotsWithTiming
            .map((s) => (
                  s,
                  const ClassTimeInfo(
                    state: ClassTimeState.future,
                    startMinutes: 0,
                    endMinutes: 0,
                  )
                ))
            .toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classified.length,
      itemBuilder: (context, idx) {
        final (slot, info) = classified[idx];
        return _buildClassCard(theme, slot, info, courses);
      },
    );
  }

  Widget _buildClassCard(
    ThemeData theme,
    TimetableSlotWithTiming slot,
    ClassTimeInfo info,
    List<Map<String, dynamic>> courses,
  ) {
    final matchingCourse = courses.firstWhere(
      (c) =>
          (c['course_code']?.toString() ?? c['courseCode']?.toString()) ==
          slot.courseCode,
      orElse: () => {},
    );

    final faculty = matchingCourse['faculty_name']?.toString() ??
        matchingCourse['facultyName']?.toString() ??
        '';
    final room = matchingCourse['room_no']?.toString() ??
        matchingCourse['roomNo']?.toString() ??
        '-';

    final isLive = info.state == ClassTimeState.ongoing;
    final isNext = info.state == ClassTimeState.upcomingNext;
    final isDone = info.state == ClassTimeState.completed;

    Color borderColor = Colors.transparent;
    if (isLive) borderColor = const Color(0xFF2D6A4F);
    if (isNext) borderColor = Colors.orangeAccent;

    return Card(
      elevation: isLive ? 3 : 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: borderColor != Colors.transparent
              ? borderColor
              : theme.dividerColor.withAlpha(40),
          width: isLive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FacultyAvatar(
                  facultyName: faculty.isNotEmpty ? faculty : slot.courseCode,
                  radius: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.courseTitle.isNotEmpty
                            ? slot.courseTitle
                            : slot.courseCode,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDone ? Colors.grey : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${slot.courseCode} • Room $room',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLive)
                  _statusBadge('LIVE NOW', const Color(0xFF2D6A4F))
                else if (isNext)
                  _statusBadge(
                    'UP NEXT (${info.minutesUntilStart ?? 0}m)',
                    Colors.orangeAccent,
                  )
                else if (isDone)
                  const Icon(LucideIcons.check, size: 16, color: Colors.grey),
              ],
            ),
            if (isLive && info.progressFraction != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: info.progressFraction,
                  backgroundColor: theme.dividerColor.withAlpha(40),
                  color: const Color(0xFF2D6A4F),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _timingForSlot(String slotStr) {
    return '09:00 - 09:50';
  }

  List<Map<String, dynamic>> _parseCourses(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Map<String, CalendarEntry> _buildCalendarMap(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return {};
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      final map = <String, CalendarEntry>{};
      for (final month in list) {
        if (month is Map<String, dynamic> && month['days'] is List) {
          for (final day in month['days'] as List<dynamic>) {
            if (day is Map<String, dynamic>) {
              final date = day['date']?.toString() ?? '';
              if (date.isNotEmpty) {
                map[date] = CalendarEntry(
                  date: date,
                  day: day['day']?.toString() ?? '',
                  dayOrder: day['dayOrder']?.toString() ??
                      day['day_order']?.toString() ??
                      '',
                  event: day['event']?.toString() ?? '',
                );
              }
            }
          }
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  Map<String, List<Map<String, String>>> _buildDaySchedule(
    List<Map<String, dynamic>> courses,
  ) {
    final map = <String, List<Map<String, String>>>{};
    for (final day in ['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5']) {
      map[day] = [];
    }

    for (final c in courses) {
      final code =
          c['course_code']?.toString() ?? c['courseCode']?.toString() ?? '';
      final title =
          c['course_title']?.toString() ?? c['courseTitle']?.toString() ?? '';
      final room = c['room_no']?.toString() ?? c['roomNo']?.toString() ?? '-';
      final slotStr = c['slot']?.toString() ?? '';

      final matches =
          RegExp(r'Day\s*([1-5])', caseSensitive: false).allMatches(slotStr);
      for (final m in matches) {
        final dayKey = 'Day ${m.group(1)}';
        map[dayKey]?.add({
          'code': code,
          'title': title,
          'room': room,
        });
      }
    }

    return map;
  }
}
