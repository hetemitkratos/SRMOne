// lib/features/attendance/attendance_screen.dart
// Attendance screen with SWR auto-refresh, dual metrics header,
// 30-day trend chart, attendance planner card, and subject breakdown.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../../domain/services/attendance_planner_math.dart';
import '../../main.dart';
import '../auth/auth_controller.dart';
import '../faculty/faculty_avatar.dart';
import 'widgets/attendance_planner_card.dart';
import 'widgets/attendance_trend_chart.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _showPlanner = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';
    final db = ref.watch(appDatabaseProvider);

    if (email.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view attendance.')),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<AttendanceCacheData>>(
        stream: db.watchAttendanceRecords(email),
        builder: (context, snapshot) {
          final records = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: () async {
              final orchestrator = ref.read(sessionSyncOrchestratorProvider);
              await orchestrator.syncAttendance(forceFreshLogin: true);
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Attendance',
                      style: TextStyle(
                        color: theme.textTheme.titleLarge?.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: _buildHeaderSummary(theme, records),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        _showPlanner
                            ? LucideIcons.chevronUp
                            : LucideIcons.calculator,
                      ),
                      tooltip: 'Toggle Attendance Planner',
                      onPressed: () {
                        setState(() {
                          _showPlanner = !_showPlanner;
                        });
                      },
                    ),
                  ],
                ),
                if (records.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            AssetPaths.onlineLearning,
                            height: 140,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No attendance data found.',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Pull down to refresh from portal',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Trend Chart
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: StreamBuilder<List<AttendanceSnapshot>>(
                        stream: db.watchAttendanceSnapshots(email),
                        builder: (context, snapSnap) {
                          return AttendanceTrendChart(
                            snapshots: snapSnap.data ?? [],
                          );
                        },
                      ),
                    ),
                  ),

                  // Collapsible Planner Card
                  if (_showPlanner)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: AttendancePlannerCard(
                          academiaEmail: email,
                          attendanceRecords: records,
                        ),
                      ),
                    ),

                  // Section Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SUBJECTS (${records.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            'Min 75% Required',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Subject Cards List
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = records[index];
                          return _buildSubjectCard(theme, item);
                        },
                        childCount: records.length,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Header Dual Metrics Summary ─────────────────────────────────────────────

  Widget _buildHeaderSummary(
    ThemeData theme,
    List<AttendanceCacheData> records,
  ) {
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

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 56),
      alignment: Alignment.topLeft,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${summary.unweightedMeanPct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: summary.unweightedMeanPct >= 75
                      ? const Color(0xFF2D6A4F)
                      : Colors.orangeAccent,
                ),
              ),
              Text(
                'Weighted: ${summary.weightedOverallPct.toStringAsFixed(1)}%',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
          Row(
            children: [
              _metricPill(
                label: '${summary.above75} Safe',
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              if (summary.below75 > 0)
                _metricPill(
                  label: '${summary.below75} Short',
                  color: Colors.redAccent,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricPill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── Subject Card ────────────────────────────────────────────────────────────

  Widget _buildSubjectCard(ThemeData theme, AttendanceCacheData item) {
    final input = AttendanceInput(
      courseCode: item.courseCode,
      courseTitle: item.courseTitle,
      hoursConducted: item.hoursConducted,
      hoursAbsent: item.hoursAbsent,
      attendancePct: item.attendancePct,
    );

    final metrics = computeSubjectCardMetrics(input);

    Color statusColor;
    if (metrics.isGood) {
      statusColor = Colors.green;
    } else if (metrics.isWarning) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.redAccent;
    }

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FacultyAvatar(
                  facultyName: item.facultyName.isNotEmpty
                      ? item.facultyName
                      : item.courseCode,
                  radius: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.courseTitle.isNotEmpty
                            ? item.courseTitle
                            : item.courseCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.courseCode} • ${item.facultyName}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(100)),
                  ),
                  child: Text(
                    '${item.attendancePct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _countLabel('Attended', '${metrics.present}', Colors.green),
                    const SizedBox(width: 12),
                    _countLabel(
                        'Absent', '${metrics.absent}', Colors.redAccent),
                    const SizedBox(width: 12),
                    _countLabel('Total', '${metrics.conducted}', Colors.grey),
                  ],
                ),
                Text(
                  metrics.isGood
                      ? (metrics.bunkable75 > 0
                          ? 'Can bunk ${metrics.bunkable75}'
                          : 'On target')
                      : 'Attend ${metrics.needed75}',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _countLabel(String title, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        Text(
          val,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
