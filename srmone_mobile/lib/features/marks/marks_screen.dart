// lib/features/marks/marks_screen.dart
// Marks screen displaying Internal Assessments (Academia) and
// Semester Results (Student Portal) as distinct isolated data streams.
// Implements Bug Fix #6 (Separate Academia vs SP marks models).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/database/app_database.dart';
import '../auth/auth_controller.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';
import '../shared/refreshable_empty.dart';

class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({super.key});

  @override
  ConsumerState<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends ConsumerState<MarksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';

    if (email.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view marks.')),
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final snapshot = ref.watch(marksProvider);
        final allMarks = snapshot.valueOrNull ?? [];
        final internalMarks = allMarks
            .where((m) => m.source == 'academia' || m.source.isEmpty)
            .toList();
        final semesterMarks =
            allMarks.where((m) => m.source == 'student_portal').toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Marks & Grades'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  icon: const Icon(LucideIcons.fileCheck, size: 16),
                  text: 'Internal Tests (${internalMarks.length})',
                ),
                Tab(
                  icon: const Icon(LucideIcons.award, size: 16),
                  text: 'Semester Results (${semesterMarks.length})',
                ),
              ],
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await ref.read(appRefresherProvider).refresh();
            },
            notificationPredicate: tabbedRefreshPredicate,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInternalMarksTab(theme, internalMarks),
                _buildSemesterMarksTab(theme, semesterMarks),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Internal Marks (Academia) ──────────────────────────────────────────────

  Widget _buildInternalMarksTab(
    ThemeData theme,
    List<MarksCacheData> internalMarks,
  ) {
    if (internalMarks.isEmpty) {
      return RefreshableEmpty(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(AssetPaths.learning, height: 140),
            const SizedBox(height: 16),
            const Text(
              'No internal test marks published yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pull down to refresh from Academia',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: internalMarks.length,
      itemBuilder: (context, index) {
        final course = internalMarks[index];
        final tests = _parseTests(course.testsJson);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withAlpha(40)),
          ),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF2D6A4F).withAlpha(30),
              child: const Icon(
                LucideIcons.graduationCap,
                color: Color(0xFF2D6A4F),
                size: 20,
              ),
            ),
            title: Text(
              course.courseTitle.isNotEmpty
                  ? course.courseTitle
                  : course.courseCode,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              '${course.courseCode} • ${course.courseType}',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            children: [
              if (tests.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No individual test marks available for this course.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: theme.dividerColor.withAlpha(50),
                            ),
                          ),
                        ),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Assessment',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Scored',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Max',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...tests.map((t) {
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                t['testName'] ?? 'Test',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '${t['scored'] ?? '-'}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF2D6A4F),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '${t['maxMarks'] ?? '-'}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─── Semester Marks (Student Portal) ────────────────────────────────────────

  Widget _buildSemesterMarksTab(
    ThemeData theme,
    List<MarksCacheData> semesterMarks,
  ) {
    if (semesterMarks.isEmpty) {
      return RefreshableEmpty(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(AssetPaths.success, height: 140),
            const SizedBox(height: 16),
            const Text(
              'No Student Portal semester results cached.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sign in with Student Portal password to view semester grades.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: semesterMarks.length,
      itemBuilder: (context, index) {
        final course = semesterMarks[index];

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.dividerColor.withAlpha(40)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withAlpha(30),
              child: const Icon(
                LucideIcons.award,
                color: Colors.blue,
                size: 20,
              ),
            ),
            title: Text(
              course.courseTitle.isNotEmpty
                  ? course.courseTitle
                  : course.courseCode,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              course.courseCode,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withAlpha(80)),
              ),
              child: const Text(
                'SP Grade',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _parseTests(String jsonStr) {
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
