// lib/features/attendance/attendance_screen.dart
// Attendance, laid out like the web app's Attendance page: the hero banner,
// mint/lavender/terracotta summary cards, the 30-day trend, the planner and
// the course breakdown. Cached rows show at once; pull down to refresh.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/attendance_planner_math.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import '../auth/auth_controller.dart';
import '../faculty/faculty_avatar.dart';
import 'attendance_planner_screen.dart';
import 'widgets/attendance_trend_chart.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';
import '../shared/ui/srm_ui.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';

    if (email.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view attendance.')),
      );
    }

    final records = [
      ...ref.watch(attendanceRecordsProvider).valueOrNull ??
          <AttendanceCacheData>[]
    ]..sort((a, b) => b.attendancePct.compareTo(a.attendancePct));
    final snapshots = ref.watch(attendanceSnapshotsProvider).valueOrNull ?? [];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(appRefresherProvider).refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: staggeredEntrance(context, [
            PageHeader(
              title: 'Attendance',
              subtitle: 'Stay above 75% in every course',
              actions: [
                if (records.isNotEmpty)
                  HeaderAction(
                    label: 'Planner',
                    icon: LucideIcons.calculator,
                    filled: true,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AttendancePlannerScreen(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const SyncSectionNotice(
              sections: [SyncSection.attendance],
              what: 'attendance',
            ),
            if (records.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: EmptyPanel(
                  illustration: AssetPaths.onlineLearning,
                  title: 'No attendance data yet',
                  message: 'Attendance comes from the Student Portal.\n'
                      'Pull down to refresh once it is connected.',
                ),
              )
            else ...[
              const SizedBox(height: 16),
              _summaryCards(records),
              const SizedBox(height: 16),
              AttendanceTrendChart(snapshots: snapshots),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: SectionTitle(
                  'Course Breakdown',
                  trailing: SoftPill(
                    label: 'Min 75%',
                    background: SrmPalette.mint,
                    foreground: SrmPalette.ink,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final r in records)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubjectCard(item: r),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _summaryCards(List<AttendanceCacheData> records) {
    final summary = computeAttendanceSummary([
      for (final r in records)
        AttendanceInput(
          courseCode: r.courseCode,
          courseTitle: r.courseTitle,
          hoursConducted: r.hoursConducted,
          hoursAbsent: r.hoursAbsent,
          attendancePct: r.attendancePct,
        ),
    ]);
    return Column(
      children: [
        PastelStatCard(
          label: 'Overall Average',
          value: summary.unweightedMeanPct.toStringAsFixed(1),
          suffix: '%',
          caption:
              'Weighted by hours: ${summary.weightedOverallPct.toStringAsFixed(1)}%',
          icon: LucideIcons.calendarCheck,
          color: SrmPalette.mint,
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PastelStatCard(
                  label: 'Above 75%',
                  value: '${summary.above75}',
                  caption: 'Courses',
                  icon: LucideIcons.trendingUp,
                  color: SrmPalette.lavender,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PastelStatCard(
                  label: 'Below 75%',
                  value: '${summary.below75}',
                  caption: 'Courses',
                  icon: LucideIcons.trendingDown,
                  color: SrmPalette.terracotta,
                  onDark: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One course, as the web's attendance cards: code pill and big percentage,
/// title, faculty, a bunk/need badge, the bar and the hour counts.
class _SubjectCard extends StatelessWidget {
  final AttendanceCacheData item;
  const _SubjectCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final m = computeSubjectCardMetrics(AttendanceInput(
      courseCode: item.courseCode,
      courseTitle: item.courseTitle,
      hoursConducted: item.hoursConducted,
      hoursAbsent: item.hoursAbsent,
      attendancePct: item.attendancePct,
    ));

    final (badge, badgeBg, badgeFg) = m.conducted == 0
        ? ('No classes yet', c.track, c.muted)
        : m.isGood
            ? m.bunkable75 > 0
                ? (
                    'Can bunk ${m.bunkable75} class${m.bunkable75 == 1 ? '' : 'es'}',
                    const Color(0xFFD1FAE5),
                    const Color(0xFF047857),
                  )
                : (
                    'On track (0 to bunk)',
                    const Color(0xFFFEF3C7),
                    const Color(0xFFB45309),
                  )
            : (
                'Need ${m.needed75} class${m.needed75 == 1 ? '' : 'es'} for 75%',
                const Color(0xFFFEE2E2),
                const Color(0xFFB91C1C),
              );

    return SrmPanel(
      radius: SrmRadii.card,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CodePill(item.courseCode),
              const Spacer(),
              Text(
                '${item.attendancePct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontFamily: SrmFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                  height: 1,
                  color: c.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.courseTitle.isNotEmpty ? item.courseTitle : item.courseCode,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.3,
              color: c.text,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.facultyName.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FacultyAvatar(facultyName: item.facultyName, radius: 12),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: Text(
                        item.facultyName
                            .replaceAll(RegExp(r'\(.*?\)'), '')
                            .trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: c.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeFg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SrmProgressBar(
            value: item.attendancePct / 100,
            color: attendanceBarColor(item.attendancePct),
            height: 12,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total: ${m.conducted}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.muted)),
              Text('Present: ${m.present}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.good)),
              Text('Absent: ${m.absent}',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: c.bad)),
            ],
          ),
        ],
      ),
    );
  }
}
