// test/features/timetable_poster_test.dart
// The shared timetable image lays out at its own 1080 px width without
// overflowing, with a cell per class and a legend entry per course.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/theme/app_theme.dart';
import 'package:srmone_mobile/features/timetable/widgets/exportable_timetable_poster.dart';

Map<String, dynamic> _course(String code, String title, List<int> hours) => {
      'courseCode': code,
      'courseTitle': title,
      'facultyName': 'Dr. Test Faculty (100001)',
      'roomNo': 'LH101',
      'schedule': [
        for (final h in hours)
          {
            'day': 'Day ${h % 5 + 1}',
            'hourIndex': h,
            'timing': [
              '08:00 - 08:50',
              '08:50 - 09:40',
              '09:45 - 10:35',
              '10:40 - 11:30',
              '11:35 - 12:25',
              '12:30 - 01:20',
              '01:25 - 02:15',
              '02:20 - 03:10',
              '03:10 - 04:00',
              '04:00 - 04:50',
            ][h % 10],
          },
      ],
    };

void main() {
  testWidgets('poster fits its own width', (tester) async {
    tester.view.physicalSize = const Size(posterWidth, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: srmLightTheme(),
      home: const SingleChildScrollView(
        child: ExportableTimetablePoster(
          studentName: 'Test Student',
          regNumber: 'RA0000000000000',
          batch: '2',
          courses: [],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('poster draws classes and a legend without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(posterWidth, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final courses = [
      _course('21AAA101T', 'INTRODUCTION TO TESTING', [0, 1, 2, 5, 9]),
      _course('21BBB202T', 'Software Things', [3, 4, 6, 7, 8]),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: srmLightTheme(),
      home: SingleChildScrollView(
        child: ExportableTimetablePoster(
          studentName: 'Test Student',
          regNumber: 'RA0000000000000',
          batch: '2',
          courses: courses,
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Introduction to Testing'), findsOneWidget);
    expect(find.text('21AAA101T'), findsWidgets);
  });
}
