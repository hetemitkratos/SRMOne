// test/domain/day_timeline_test.dart
// The timetable's timeline: merged periods, breaks and 12-hour times.

import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/domain/services/current_class_detector.dart';
import 'package:srmone_mobile/domain/services/day_timeline.dart';

TimetableSlotWithTiming _slot(String code, String timing, int hour) =>
    TimetableSlotWithTiming(
      courseCode: code,
      courseTitle: 'Course $code',
      timing: timing,
      hourIndex: hour,
      day: 'Day 1',
    );

void main() {
  group('buildDayTimeline', () {
    test('merges back-to-back periods of one course', () {
      final t = buildDayTimeline([
        _slot('A', '08:00 - 08:50', 1),
        _slot('A', '08:50 - 09:40', 2),
        _slot('A', '09:45 - 10:35', 3),
        _slot('B', '10:40 - 11:30', 4),
      ]);
      expect(t, hasLength(2));
      final a = t[0] as ClassBlock;
      expect(a.periods, 3);
      expect(a.start, 8 * 60);
      expect(a.end, 10 * 60 + 35);
      expect((t[1] as ClassBlock).courseCode, 'B');
    });

    test('puts a break between classes far apart', () {
      final t = buildDayTimeline([
        _slot('B', '12:30 - 01:20', 6),
        _slot('A', '08:00 - 08:50', 1),
      ]);
      expect(t, hasLength(3));
      final gap = t[1] as BreakGap;
      expect(gap.start, 8 * 60 + 50);
      expect(gap.end, 12 * 60 + 30);
    });

    test('does not merge the same course across a break', () {
      final t = buildDayTimeline([
        _slot('A', '08:00 - 08:50', 1),
        _slot('A', '12:30 - 01:20', 6),
      ]);
      expect(t.whereType<ClassBlock>(), hasLength(2));
      expect(t.whereType<BreakGap>(), hasLength(1));
    });

    test('keeps slots whose timing cannot be read', () {
      final t = buildDayTimeline([_slot('A', 'TBA', 1)]);
      expect((t.single as ClassBlock).start, isNull);
    });
  });

  test('formats SRM times in 12-hour form', () {
    expect(formatClock(14 * 60 + 20), '2:20 PM');
    expect(formatClock(12 * 60), '12:00 PM');
    expect(formatClock(8 * 60 + 5), '8:05 AM');
    expect(formatTiming('02:20 - 03:10'), '2:20 – 3:10 PM');
    expect(formatTiming('11:05 - 12:45'), '11:05 AM – 12:45 PM');
    expect(formatTiming('TBA'), 'TBA');
  });

  test('says when a class starts', () {
    expect(startsIn(25, 600), 'in 25 min');
    expect(startsIn(574, 14 * 60 + 20), 'at 2:20 PM');
  });

  test('title-cases only shouting titles', () {
    expect(tidyTitle('INTRODUCTION TO ROBOTICS'), 'Introduction to Robotics');
    expect(tidyTitle('COMPILER DESIGN II'), 'Compiler Design II');
    expect(tidyTitle('Deep Learning'), 'Deep Learning');
    expect(tidyTitle('21CSE496TA'), '21CSE496TA');
    expect(tidyTitle('LAB 21CSC404P'), 'Lab 21CSC404P');
  });
}
