// test/features/attendance_trend_range_test.dart
// The trend chart's y-axis must always contain every point, so the line can
// never be drawn below the chart and over the course list.

import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/features/attendance/widgets/attendance_trend_chart.dart';

void main() {
  test('keeps 75% and 100% in view for high attendance', () {
    final r = trendAxisRange([88, 92, 95]);
    expect(r.min, lessThanOrEqualTo(75));
    expect(r.max, 100);
  });

  test('drops the floor below the lowest point', () {
    for (final low in [39.0, 31.2, 12.5, 0.0]) {
      final r = trendAxisRange([low, 60, 70]);
      expect(r.min, lessThanOrEqualTo(low), reason: 'lowest point $low');
      expect(r.min, greaterThanOrEqualTo(0));
    }
  });

  test('never goes below zero', () {
    expect(trendAxisRange([2]).min, 0);
  });
}
