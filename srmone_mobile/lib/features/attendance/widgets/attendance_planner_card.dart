// lib/features/attendance/widgets/attendance_planner_card.dart
// Interactive attendance planner with "Reach Target" and "Plan Holiday" modes.
// Integrates Bug Fix #2 (T=100 division-by-zero guard) and holiday impact simulation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/asset_paths.dart';
import '../../../core/database/app_database.dart';
import '../../../domain/services/attendance_planner_math.dart';
import '../../../domain/services/calendar_day_resolver.dart';
import '../../shared/cached_data_providers.dart';

class AttendancePlannerCard extends ConsumerStatefulWidget {
  final String academiaEmail;
  final List<AttendanceCacheData> attendanceRecords;

  const AttendancePlannerCard({
    super.key,
    required this.academiaEmail,
    required this.attendanceRecords,
  });

  @override
  ConsumerState<AttendancePlannerCard> createState() =>
      _AttendancePlannerCardState();
}

class _AttendancePlannerCardState extends ConsumerState<AttendancePlannerCard>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _targetPercentage = 75;

  DateTime _holidayFrom = DateTime.now().add(const Duration(days: 1));
  DateTime _holidayTo = DateTime.now().add(const Duration(days: 3));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AttendanceInput> get _inputs {
    return widget.attendanceRecords.map((r) {
      return AttendanceInput(
        courseCode: r.courseCode,
        courseTitle: r.courseTitle,
        hoursConducted: r.hoursConducted,
        hoursAbsent: r.hoursAbsent,
        attendancePct: r.attendancePct,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                icon: Icon(LucideIcons.target, size: 18),
                text: 'Reach Target',
              ),
              Tab(
                icon: Icon(LucideIcons.plane, size: 18),
                text: 'Plan Holiday',
              ),
            ],
          ),
          const Divider(height: 1),
          SizedBox(
            height: 440,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildReachTargetTab(theme),
                _buildPlanHolidayTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reach Target Tab ────────────────────────────────────────────────────────

  Widget _buildReachTargetTab(ThemeData theme) {
    final results = computeReachTarget(_inputs, _targetPercentage);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: $_targetPercentage%',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _targetPercentage.toDouble(),
                  min: 50,
                  max: 100,
                  divisions: 10,
                  label: '$_targetPercentage%',
                  onChanged: (val) {
                    setState(() {
                      _targetPercentage = val.round();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: results.isEmpty
              ? const Center(child: Text('No attendance data available'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return _buildReachTargetItem(theme, item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReachTargetItem(ThemeData theme, ReachTargetResult item) {
    if (item.isUnreachable100) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withAlpha(80)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.circleAlert,
                color: Colors.redAccent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.courseTitle.isNotEmpty
                        ? item.courseTitle
                        : item.courseCode,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '100% target is mathematically impossible because absences cannot be undone.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isSafe = item.alreadyAbove;
    final badgeColor = isSafe ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.courseTitle.isNotEmpty
                      ? item.courseTitle
                      : item.courseCode,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Current: ${item.pct.toStringAsFixed(1)}% (${item.present}/${item.conducted})',
                  style:
                      theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withAlpha(100)),
            ),
            child: Text(
              isSafe
                  ? (item.bunkable > 0 ? 'Bunk ${item.bunkable}' : 'On Track')
                  : 'Attend ${item.needed}',
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Plan Holiday Tab ────────────────────────────────────────────────────────

  Widget _buildPlanHolidayTab(ThemeData theme) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Consumer(
      builder: (context, ref, _) {
        final timetableSlots = ref.watch(_plannerSlotsProvider);

        return Consumer(
          builder: (context, ref, _) {
            final calendarMap =
                ref.watch(calendarMapProvider(currentSemester()));

            final results = computePlanHoliday(
              fromDate: _holidayFrom,
              toDate: _holidayTo,
              records: _inputs,
              timetableSlots: timetableSlots,
              // Day orders come from the academic calendar; without one,
              // fall back to the weekday guess.
              calendarResolver: calendarMap.isEmpty
                  ? null
                  : (dt) {
                      final status =
                          CalendarDayResolver.getDayStatus(calendarMap, dt);
                      return ResolvedDayStatus(
                        isWorking: status.isWorkingDay,
                        dayLabel: status.isWorkingDay ? status.dayLabel : null,
                      );
                    },
            );

            return Column(
              children: [
                // Date picker trigger button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(LucideIcons.calendarRange, size: 16),
                    label: Text(
                      '${dateFormat.format(_holidayFrom)} – ${dateFormat.format(_holidayTo)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 120)),
                        initialDateRange: DateTimeRange(
                          start: _holidayFrom,
                          end: _holidayTo,
                        ),
                      );
                      if (picked != null) {
                        setState(() {
                          _holidayFrom = picked.start;
                          _holidayTo = picked.end;
                        });
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                AssetPaths.travelPlans,
                                height: 80,
                              ),
                              const SizedBox(height: 12),
                              const Text('No courses mapped to holiday period'),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = results[index];
                            final willDrop = item.willDropBelow75;
                            final color = willDrop
                                ? Colors.redAccent
                                : (item.missed > 0
                                    ? Colors.orange
                                    : Colors.green);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: willDrop
                                      ? Colors.red.withAlpha(120)
                                      : theme.dividerColor.withAlpha(50),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.courseTitle.isNotEmpty
                                              ? item.courseTitle
                                              : item.courseCode,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item.currentPct.toStringAsFixed(1)}% → ${item.newPct.toStringAsFixed(1)}% (-${item.drop.toStringAsFixed(1)}%)',
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Misses ${item.missed}',
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (willDrop)
                                        Text(
                                          'Need ${item.recoveryNeeded} to recover',
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// Built once per timetable change rather than on every rebuild of the
// planner (each date pick rebuilds it).
final _plannerSlotsProvider = Provider<List<TimetableSlot>>(
    (ref) => timetableSlotsFromCourses(ref.watch(timetableCoursesProvider)));
