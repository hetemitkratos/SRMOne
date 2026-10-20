// test/features/marks_grouping_test.dart
// Student Portal internal totals show as internal marks, next to (never
// summed with) Academia's tests, with a course title filled in.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';
import 'package:srmone_mobile/features/marks/marks_screen.dart';

MarksCacheData _row(String code, String source, List<Map<String, Object>> tests,
        {String title = '', String type = ''}) =>
    MarksCacheData(
      academiaEmail: 'ab1234@srmist.edu.in',
      courseCode: code,
      courseTitle: title,
      courseType: type,
      source: source,
      testsJson: jsonEncode(tests),
      updatedAt: 0,
    );

void main() {
  test('a portal-only course shows its internal total and a looked-up title',
      () {
    final courses = groupCourseMarks([
      _row('21CSC403T', 'student_portal', [
        {'testName': 'Total (Internal)', 'scored': 15.0, 'maxMarks': 20.0},
      ]),
    ], {
      '21CSC403T': 'Software Security'
    });

    final c = courses.single;
    expect(c.courseTitle, 'Software Security');
    expect(c.portalTotal, (scored: 15.0, max: 20.0));
    expect(c.academiaTests, isEmpty);
  });

  test('both portals for one course stay separate in one card', () {
    final courses = groupCourseMarks([
      _row(
          '21CSE493T',
          'academia',
          [
            {'testName': 'CLA-1', 'scored': 9, 'maxMarks': 10},
          ],
          title: 'Deep Learning',
          type: 'Theory'),
      _row('21cse493t', 'student_portal', [
        {'testName': 'Total (Internal)', 'scored': 15.9, 'maxMarks': 20},
      ]),
    ], const {});

    final c = courses.single;
    expect(c.courseTitle, 'Deep Learning');
    expect(c.academiaTests.single['testName'], 'CLA-1');
    expect(c.portalTotal?.scored, 15.9);
  });

  test('unreadable portal marks give no total instead of a crash', () {
    final courses = groupCourseMarks([
      _row('X1', 'student_portal', [
        {'testName': 'Total (Internal)', 'scored': 'AB', 'maxMarks': 20},
      ]),
    ], const {});
    expect(courses.single.portalTotal, isNull);
  });
}
