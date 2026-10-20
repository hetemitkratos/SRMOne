// lib/domain/services/day_timeline.dart
// Turns a day's timetable slots into a timeline: back-to-back periods of the
// same course merge into one block, and gaps between classes become breaks.
// Also formats SRM's ambiguous "02:20" clock times as "2:20 PM".

import 'current_class_detector.dart';

/// One row of a day's timeline.
sealed class TimelineEntry {
  const TimelineEntry();
}

/// One or more consecutive periods of the same course.
final class ClassBlock extends TimelineEntry {
  final String courseCode;
  final String courseTitle;

  /// The periods merged into this block, in order.
  final List<TimetableSlotWithTiming> slots;

  /// Minutes since midnight, or null when a timing could not be read.
  final int? start;
  final int? end;

  const ClassBlock({
    required this.courseCode,
    required this.courseTitle,
    required this.slots,
    required this.start,
    required this.end,
  });

  int get periods => slots.length;

  /// Whether [minutes] (since midnight) falls inside this block.
  bool contains(int minutes) =>
      start != null && end != null && minutes >= start! && minutes < end!;
}

/// Free time between two classes.
final class BreakGap extends TimelineEntry {
  final int start;
  final int end;

  const BreakGap({required this.start, required this.end});

  int get minutes => end - start;
}

/// Builds the timeline for [slots] (one day, any order).
///
/// Periods of the same course merge when the next one starts within
/// [mergeGap] minutes of the previous one ending (SRM's 5-minute changeovers);
/// longer gaps of at least [minBreak] minutes become a [BreakGap].
List<TimelineEntry> buildDayTimeline(
  List<TimetableSlotWithTiming> slots, {
  int mergeGap = 10,
  int minBreak = 15,
}) {
  final sorted = [...slots]..sort((a, b) => a.hourIndex.compareTo(b.hourIndex));
  final blocks = <ClassBlock>[];

  for (final s in sorted) {
    final t = CurrentClassDetector.parseTiming(s.timing);
    final last = blocks.isEmpty ? null : blocks.last;
    final canMerge = last != null &&
        last.courseCode == s.courseCode &&
        t != null &&
        last.end != null &&
        t.$1 - last.end! <= mergeGap;
    if (canMerge) {
      blocks[blocks.length - 1] = ClassBlock(
        courseCode: last.courseCode,
        courseTitle: last.courseTitle,
        slots: [...last.slots, s],
        start: last.start,
        end: t.$2,
      );
    } else {
      blocks.add(ClassBlock(
        courseCode: s.courseCode,
        courseTitle: s.courseTitle,
        slots: [s],
        start: t?.$1,
        end: t?.$2,
      ));
    }
  }

  final out = <TimelineEntry>[];
  for (final (i, b) in blocks.indexed) {
    if (i > 0) {
      final prevEnd = blocks[i - 1].end;
      if (prevEnd != null && b.start != null && b.start! - prevEnd >= minBreak) {
        out.add(BreakGap(start: prevEnd, end: b.start!));
      }
    }
    out.add(b);
  }
  return out;
}

/// 860 → "2:20 PM"; with [suffix] false, "2:20".
String formatClock(int minutes, {bool suffix = true}) {
  final h24 = (minutes ~/ 60) % 24;
  final m = minutes % 60;
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final mm = m.toString().padLeft(2, '0');
  return suffix ? '$h12:$mm ${h24 < 12 ? 'AM' : 'PM'}' : '$h12:$mm';
}

/// "02:20 - 03:10" → "2:20 – 3:10 PM", and "11:05 - 12:45" →
/// "11:05 AM – 12:45 PM". Unreadable timings come back unchanged.
String formatTiming(String timing) {
  final t = CurrentClassDetector.parseTiming(timing);
  if (t == null) return timing;
  return formatRange(t.$1, t.$2);
}

/// A start–end range in 12-hour time, naming AM/PM once when both match.
String formatRange(int start, int end) {
  final samePeriod = (start ~/ 720) == (end ~/ 720);
  return samePeriod
      ? '${formatClock(start, suffix: false)} – ${formatClock(end)}'
      : '${formatClock(start)} – ${formatClock(end)}';
}

/// How long until a class: "in 25 min" within the hour, else "at 2:20 PM".
String startsIn(int minutesUntil, int startMinutes) =>
    minutesUntil <= 60 ? 'in $minutesUntil min' : 'at ${formatClock(startMinutes)}';

/// A duration such as "50 min" or "1 h 35 min".
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// Small words kept lower case inside a title.
const _minorWords = {
  'a', 'an', 'and', 'as', 'at', 'by', 'for', 'in', 'of', 'on', 'or', 'the',
  'to', 'with',
};

/// Title-cases [text] when it is ALL CAPS (as some portal pages send course
/// names), keeping roman numerals and words with digits (course codes);
/// other text is returned unchanged.
String tidyTitle(String text) {
  final letters = text.replaceAll(RegExp(r'[^A-Za-z]'), '');
  if (letters.isEmpty || letters != letters.toUpperCase()) return text;
  final words = text.split(' ');
  return [
    for (final (i, raw) in words.indexed)
      if (RegExp(r'\d').hasMatch(raw))
        raw
      else if (raw.toLowerCase() case final w when
          RegExp(r'^(i|ii|iii|iv|v|vi|vii|viii|ix|x)$').hasMatch(w))
        w.toUpperCase()
      else if (raw.toLowerCase() case final w when i > 0 && _minorWords.contains(w))
        w
      else if (raw.isEmpty)
        raw
      else
        raw[0].toUpperCase() + raw.substring(1).toLowerCase(),
  ].join(' ');
}
