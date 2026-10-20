// test/features/calendar_month_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/features/calendar/calendar_screen.dart';

void main() {
  final oct = DateTime(2026, 10, 16);

  test('matches Academia month headers for the current month', () {
    expect(isCurrentMonth("Oct '26", oct), isTrue);
    expect(isCurrentMonth('October 2026', oct), isTrue);
  });

  test('rejects other months and years', () {
    expect(isCurrentMonth("Jul '26", oct), isFalse);
    expect(isCurrentMonth("Oct '25", oct), isFalse);
    expect(isCurrentMonth('Month1', oct), isFalse);
  });
}
