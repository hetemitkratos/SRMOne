// lib/features/calendar/calendar_screen.dart
// Academic calendar screen with Odd/Even semester toggle,
// unified day-order resolution, and holiday highlights.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import '../auth/auth_controller.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String _selectedSemester = semesterFor(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';

    if (email.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view academic calendar.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Calendar'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'odd',
                  label: Text('Odd Semester'),
                  icon: Icon(LucideIcons.calendarDays, size: 16),
                ),
                ButtonSegment(
                  value: 'even',
                  label: Text('Even Semester'),
                  icon: Icon(LucideIcons.calendarClock, size: 16),
                ),
              ],
              selected: {_selectedSemester},
              onSelectionChanged: (set) {
                setState(() {
                  _selectedSemester = set.first;
                });
              },
            ),
          ),
        ),
      ),
      body: Consumer(
        builder: (context, ref, _) {
          final snapshot = ref.watch(calendarProvider(_selectedSemester));
          final calendarData = snapshot.valueOrNull;
          final months = _parseMonths(calendarData?.monthsJson);

          return RefreshIndicator(
            onRefresh: () async {
              await ref
                  .read(appRefresherProvider)
                  .refresh(waitForDetails: true);
            },
            child: months.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(AssetPaths.calendar, height: 140),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_selectedSemester.toUpperCase()} semester calendar cached.',
                          style:
                              const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pull down to refresh from Academia',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: months.length,
                    itemBuilder: (context, idx) {
                      final monthObj = months[idx];
                      return _buildMonthCard(theme, monthObj);
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildMonthCard(ThemeData theme, Map<String, dynamic> month) {
    final monthName = month['month']?.toString() ?? 'Month';
    final days = (month['days'] as List<dynamic>?) ?? [];

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2D6A4F).withAlpha(30),
          child: const Icon(
            LucideIcons.calendar,
            color: Color(0xFF2D6A4F),
            size: 20,
          ),
        ),
        title: Text(
          monthName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          '${days.length} days recorded',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: days.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, dayIdx) {
              final d = days[dayIdx] as Map<String, dynamic>;
              return _buildDayRow(theme, d);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(ThemeData theme, Map<String, dynamic> day) {
    final date = day['date']?.toString() ?? '';
    final dayOfWeek = day['day']?.toString() ?? '';
    final dayOrder =
        day['dayOrder']?.toString() ?? day['day_order']?.toString() ?? '';
    final event = day['event']?.toString() ?? '';
    final isHoliday = day['isHoliday'] == true ||
        day['is_holiday'] == true ||
        event.toLowerCase().contains('holiday');

    // Parse day number from date YYYY-MM-DD
    final dateParts = date.split('-');
    final dayNum = dateParts.length >= 3 ? dateParts[2] : date;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Date number container
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isHoliday
                  ? Colors.red.withAlpha(25)
                  : theme.dividerColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Text(
                  dayNum,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isHoliday ? Colors.redAccent : null,
                  ),
                ),
                Text(
                  dayOfWeek,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Day order / Event detail
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dayOrder.isNotEmpty && dayOrder != '-')
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6A4F).withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Day $dayOrder',
                          style: const TextStyle(
                            color: Color(0xFF2D6A4F),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (event.isNotEmpty) const SizedBox(width: 8),
                    ],
                  ),
                if (event.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      event,
                      style: TextStyle(
                        fontSize: 12,
                        color: isHoliday ? Colors.redAccent : Colors.grey[300],
                        fontWeight:
                            isHoliday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                if (dayOrder.isEmpty || dayOrder == '-')
                  if (event.isEmpty)
                    const Text(
                      'No classes',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
              ],
            ),
          ),

          if (isHoliday)
            const Icon(
              LucideIcons.sun,
              size: 18,
              color: Colors.redAccent,
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _parseMonths(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
