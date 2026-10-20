// lib/features/calendar/calendar_screen.dart
// Academic calendar, laid out like the web app's Calendar page: the hero
// with an Odd/Even toggle, a month grid (today black, events mint,
// holidays terracotta, day orders under each date) with month pills, and
// the month's events list.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/services/calendar_day_resolver.dart';
import '../../domain/services/day_timeline.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import '../../domain/services/timetable_schedule.dart';
import '../auth/auth_controller.dart';
import '../shared/app_refresher.dart';
import '../shared/cached_data_providers.dart';
import '../shared/ui/srm_ui.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  String _selectedSemester = semesterFor(DateTime.now());

  /// The month shown, by index into the semester's months; null opens on
  /// the current month (or the first).
  int? _monthIdx;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';

    if (email.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view academic calendar.')),
      );
    }

    final months = ref.watch(calendarMonthsProvider(_selectedSemester));
    final current =
        months.indexWhere((m) => isCurrentMonth(m['month']?.toString() ?? ''));
    final idx = months.isEmpty
        ? 0
        : (_monthIdx ?? (current < 0 ? 0 : current))
            .clamp(0, months.length - 1);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(appRefresherProvider).refresh(waitForDetails: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: staggeredEntrance(context, [
            PageHeader(
              title: 'Calendar',
              subtitle: 'Day orders, events and holidays',
              actions: [
                PillToggle<String>(
                  options: const [('odd', 'Odd'), ('even', 'Even')],
                  value: _selectedSemester,
                  onChanged: (s) => setState(() {
                    _selectedSemester = s;
                    _monthIdx = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const SyncSectionNotice(
              sections: [SyncSection.calendar],
              what: 'the calendar',
            ),
            if (months.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: EmptyPanel(
                  illustration: AssetPaths.calendar,
                  title:
                      'No ${_selectedSemester == 'odd' ? 'odd' : 'even'} semester calendar saved',
                  message: 'Pull down to refresh from Academia.',
                ),
              )
            else ...[
              const SizedBox(height: 16),
              _MonthGrid(
                months: months,
                index: idx,
                currentIndex: current,
                onPick: (i) => setState(() => _monthIdx = i),
              ),
              const SizedBox(height: 16),
              _EventsPanel(month: months[idx]),
            ],
          ]),
        ),
      ),
    );
  }
}

/// One calendar day, read from the stored month JSON.
class _Day {
  final DateTime? date;
  final int dayNum;
  final String weekday;
  final String? dayOrder;
  final String event;
  final bool isHoliday;

  _Day(Map<String, dynamic> d)
      : date = DateTime.tryParse(d['date']?.toString() ?? ''),
        dayNum =
            int.tryParse((d['date']?.toString() ?? '').split('-').last) ?? 0,
        weekday = d['day']?.toString() ?? '',
        dayOrder = switch (
            d['dayOrder']?.toString() ?? d['day_order']?.toString() ?? '') {
          '' || '-' => null,
          final o => o,
        },
        event = (d['event']?.toString() ?? '').trim(),
        isHoliday = d['isHoliday'] == true ||
            d['is_holiday'] == true ||
            (d['event']?.toString() ?? '').toLowerCase().contains('holiday');

  bool get isToday {
    final n = DateTime.now();
    return date != null &&
        date!.year == n.year &&
        date!.month == n.month &&
        date!.day == n.day;
  }
}

List<_Day> _days(Map<String, dynamic> month) => [
      for (final d in (month['days'] as List<dynamic>? ?? const []))
        if (d is Map<String, dynamic>) _Day(d),
    ];

/// The month grid with arrows and month pills.
class _MonthGrid extends StatelessWidget {
  final List<Map<String, dynamic>> months;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onPick;

  const _MonthGrid({
    required this.months,
    required this.index,
    required this.currentIndex,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final month = months[index];
    final name = month['month']?.toString() ?? 'Month';
    final days = _days(month);
    final byNum = {for (final d in days) d.dayNum: d};
    // Lay the grid out from the month itself, so a day missing from the
    // portal's list leaves a gap instead of shifting the rest.
    final start = CalendarDayResolver.parseMonthName(name) ??
        days.map((d) => d.date).whereType<DateTime>().firstOrNull;
    final count = start == null
        ? days.length
        : DateTime(start.year, start.month + 1, 0).day;
    // Columns start on Sunday, as on the web.
    final lead =
        start == null ? 0 : DateTime(start.year, start.month, 1).weekday % 7;

    return SrmPanel(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        children: [
          Row(
            children: [
              RoundIconButton(
                icon: LucideIcons.chevronLeft,
                tooltip: 'Previous month',
                onPressed: () =>
                    onPick((index - 1 + months.length) % months.length),
              ),
              Expanded(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SrmFonts.display,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: c.text,
                  ),
                ),
              ),
              RoundIconButton(
                icon: LucideIcons.chevronRight,
                tooltip: 'Next month',
                onPressed: () => onPick((index + 1) % months.length),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: months.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final selected = i == index;
                final isNow = i == currentIndex;
                return Semantics(
                  button: true,
                  selected: selected,
                  child: GestureDetector(
                    onTap: () => onPick(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? c.hero
                            : isNow
                                ? SrmPalette.terracotta.withAlpha(26)
                                : c.track,
                        borderRadius: BorderRadius.circular(99),
                        border: !selected && isNow
                            ? Border.all(
                                color: SrmPalette.terracotta.withAlpha(77))
                            : null,
                      ),
                      child: Text(
                        '${months[i]['month'] ?? ''}${isNow && !selected ? ' ●' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? c.onHero
                              : isNow
                                  ? SrmPalette.terracottaText
                                  : c.muted,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final w in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.faint,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.82,
            children: [
              for (var i = 0; i < lead; i++) const SizedBox.shrink(),
              if (start == null)
                for (final d in days) _DayCell(day: d)
              else
                for (var n = 1; n <= count; n++)
                  byNum[n] != null
                      ? _DayCell(day: byNum[n]!)
                      : _DayCell(
                          day: _Day({
                            'date': '${start.year}-'
                                '${start.month.toString().padLeft(2, '0')}-'
                                '${n.toString().padLeft(2, '0')}',
                          }),
                        ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _legend(context, c.hero, 'Today'),
              _legend(context, SrmPalette.mint, 'Event'),
              _legend(context, SrmPalette.terracotta.withAlpha(90), 'Holiday'),
              _legend(context, c.card, 'Class day', border: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label,
      {bool border = false}) {
    final c = SrmColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border ? Border.all(color: c.border) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: c.muted)),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final _Day day;
  const _DayCell({required this.day});

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final today = day.isToday;
    final hasEvent = day.event.isNotEmpty;

    final (Color bg, Color fg, BoxBorder? border) = today
        ? (c.hero, c.onHero, null)
        : day.isHoliday
            ? (
                SrmPalette.terracotta.withAlpha(36),
                SrmPalette.terracottaText,
                null,
              )
            : hasEvent
                ? (SrmPalette.mint, SrmPalette.ink, null)
                : day.dayOrder != null
                    ? (c.card, c.text, Border.all(color: c.border))
                    : (c.track.withAlpha(150), c.faint, null);

    final label = [
      '${day.weekday} ${day.dayNum}',
      if (today) 'today',
      if (day.dayOrder != null) 'day order ${day.dayOrder}',
      if (day.isHoliday) 'holiday',
      if (hasEvent) day.event,
    ].join(', ');

    return Semantics(
      label: label,
      button: true,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => showModalBottomSheet<void>(
            context: context,
            showDragHandle: true,
            builder: (_) => _DaySheet(day: day),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${day.dayNum}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.1,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 3),
                if (hasEvent && !day.isHoliday)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: today ? c.onHero : SrmPalette.terracotta,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  Text(
                    day.isHoliday
                        ? 'HOL'
                        : day.dayOrder != null
                            ? 'D${day.dayOrder}'
                            : '',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: fg.withAlpha(150),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The month's events, as the web's beige event cards.
class _EventsPanel extends StatelessWidget {
  final Map<String, dynamic> month;
  const _EventsPanel({required this.month});

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    final events = [
      for (final d in _days(month))
        if (d.event.isNotEmpty) d,
    ];

    return SrmPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                    color: SrmPalette.lavender, shape: BoxShape.circle),
                child: const Icon(LucideIcons.calendarDays,
                    size: 18, color: SrmPalette.ink),
              ),
              const SizedBox(width: 10),
              const Expanded(child: SectionTitle('Events', size: 20)),
              if (events.isNotEmpty)
                SoftPill(
                  label: '${events.length}',
                  background: c.track,
                  foreground: c.faint,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.track,
                borderRadius: BorderRadius.circular(SrmRadii.card),
              ),
              child: Text(
                'No events this month.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13, color: c.muted),
              ),
            )
          else
            for (final e in events) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: e.isHoliday
                      ? SrmPalette.terracotta.withAlpha(46)
                      : SrmPalette.beige,
                  borderRadius: BorderRadius.circular(SrmRadii.card),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: SrmPalette.slate200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${e.dayNum}',
                                style: const TextStyle(
                                  fontFamily: SrmFonts.display,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: SrmPalette.ink,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                e.weekday.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: SrmPalette.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (e.isToday)
                          SoftPill(
                            label: 'TODAY',
                            background: SrmPalette.terracotta.withAlpha(26),
                            foreground: SrmPalette.terracottaText,
                          )
                        else if (e.isHoliday)
                          const SoftPill(
                            label: 'HOLIDAY',
                            icon: LucideIcons.sun,
                            background: Colors.white,
                            foreground: SrmPalette.terracottaText,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.event,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.3,
                        color: SrmPalette.ink,
                      ),
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
}

/// Whether an Academia month header such as "Oct '26" names the current
/// month.
bool isCurrentMonth(String header, [DateTime? now]) {
  final month = CalendarDayResolver.parseMonthName(header);
  final today = now ?? DateTime.now();
  return month != null &&
      month.year == today.year &&
      month.month == today.month;
}

/// A day's details: weekday, day order, event, and that day order's classes.
class _DaySheet extends ConsumerWidget {
  final _Day day;
  const _DaySheet({required this.day});

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = SrmColors.of(context);
    final d = day.date;
    final heading = d == null
        ? '${day.dayNum}'
        : '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
    final order = day.dayOrder;
    final blocks = order == null || day.isHoliday
        ? const <ClassBlock>[]
        : buildDayTimeline(TimetableSchedule.slotsForDay(
                ref.watch(timetableCoursesProvider), 'Day $order'))
            .whereType<ClassBlock>()
            .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              style: TextStyle(
                fontFamily: SrmFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: c.text,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (day.isToday)
                  SoftPill(
                    label: 'TODAY',
                    background: SrmPalette.terracotta.withAlpha(26),
                    foreground: SrmPalette.terracottaText,
                  ),
                if (day.isHoliday)
                  SoftPill(
                    label: 'HOLIDAY',
                    icon: LucideIcons.sun,
                    background: SrmPalette.terracotta.withAlpha(36),
                    foreground: SrmPalette.terracottaText,
                  )
                else if (order != null)
                  SoftPill(
                    label: 'DAY ORDER $order',
                    background: c.hero,
                    foreground: c.onHero,
                  )
                else
                  SoftPill(
                    label: 'NO CLASSES',
                    background: c.track,
                    foreground: c.muted,
                  ),
              ],
            ),
            if (day.event.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                day.event,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15, color: c.text),
              ),
            ],
            if (blocks.isNotEmpty) ...[
              const SizedBox(height: 18),
              const EyebrowLabel('Classes'),
              const SizedBox(height: 8),
              for (final b in blocks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 70,
                        child: Text(
                          b.start == null ? '—' : formatClock(b.start!),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: c.muted),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tidyTitle(b.courseTitle.isNotEmpty
                              ? b.courseTitle
                              : b.courseCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
