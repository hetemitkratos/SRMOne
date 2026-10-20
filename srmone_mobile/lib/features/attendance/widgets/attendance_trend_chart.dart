// lib/features/attendance/widgets/attendance_trend_chart.dart
// 30-day attendance trend line chart using fl_chart with a dashed 75%
// threshold, styled like the web app's "Attendance Trend" card.

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/ui/srm_ui.dart';

/// The web chart's line and threshold colours.
const _lineColor = Color(0xFF00D9A3);
const _thresholdColor = Color(0xFFF97316);

/// The y-axis range for [values]: always shows 75% and 100%, and starts at
/// the 10% step below the lowest value, so the line never leaves the chart.
({double min, double max}) trendAxisRange(Iterable<double> values) {
  final lowest = values.isEmpty ? 75.0 : values.reduce(math.min);
  final min = (math.min(lowest, 75.0) / 10).floor() * 10.0 - 10;
  return (min: math.max(0, min), max: 100);
}

class AttendanceTrendChart extends StatelessWidget {
  final List<AttendanceSnapshot> snapshots;

  const AttendanceTrendChart({
    super.key,
    required this.snapshots,
  });

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);

    final header = SectionTitle(
      'Attendance Trend',
      trailing: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: SrmPalette.mint.withAlpha(60),
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.chartLine,
            size: 20, color: SrmPalette.mintText),
      ),
    );

    if (snapshots.length < 2) {
      return SrmPanel(
        child: Column(
          children: [
            header,
            const SizedBox(height: 20),
            Text(
              'No attendance history yet',
              style: TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14, color: c.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'A snapshot is saved each day the app syncs; the trend appears '
              'after two.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: c.faint),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    }

    // Sort snapshots ascending by date
    final sorted = List<AttendanceSnapshot>.from(snapshots)
      ..sort((a, b) => a.snapshotDate.compareTo(b.snapshotDate));

    final spots = <FlSpot>[
      for (int i = 0; i < sorted.length; i++)
        FlSpot(i.toDouble(), sorted[i].overallPercentage.clamp(0, 100)),
    ];
    final range = trendAxisRange(spots.map((s) => s.y));
    final labelStyle = TextStyle(color: c.faint, fontSize: 10);

    return SrmPanel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 4),
          Text('Last ${sorted.length} days synced',
              style: TextStyle(fontSize: 12, color: c.muted)),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (sorted.length - 1).toDouble(),
                minY: range.min,
                maxY: range.max,
                // Keep the line and its fill inside the plot area.
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: c.border,
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: range.max - range.min > 40 ? 20 : 10,
                      getTitlesWidget: (val, meta) =>
                          Text('${val.toInt()}%', style: labelStyle),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: math.max(1, (sorted.length / 4).ceilToDouble()),
                      getTitlesWidget: (val, meta) {
                        final idx = val.toInt();
                        if (idx >= 0 && idx < sorted.length) {
                          final dateParts = sorted[idx].snapshotDate.split('-');
                          if (dateParts.length >= 3) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('${dateParts[2]}/${dateParts[1]}',
                                  style: labelStyle),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 75,
                      color: _thresholdColor,
                      strokeWidth: 1.5,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                          color: _thresholdColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        labelResolver: (_) => '75%',
                      ),
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    // A curve through steep points can swing past them.
                    preventCurveOverShooting: true,
                    color: _lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: sorted.length <= 14,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 3.5,
                        color: _lineColor,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      // Fill down to the axis floor, not below the chart.
                      cutOffY: range.min,
                      applyCutOffY: true,
                      gradient: LinearGradient(
                        colors: [
                          _lineColor.withAlpha(70),
                          _lineColor.withAlpha(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => SrmPalette.ink,
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final date = (idx >= 0 && idx < sorted.length)
                            ? sorted[idx].snapshotDate
                            : '';
                        return LineTooltipItem(
                          '$date\n${spot.y.toStringAsFixed(1)}%',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
