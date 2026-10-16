// test/widget_test.dart
// Widget smoke and interaction tests for Phase 4 UI components.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';
import 'package:srmone_mobile/features/attendance/widgets/attendance_trend_chart.dart';
import 'package:srmone_mobile/features/auth/biometric_lock_screen.dart';
import 'package:srmone_mobile/features/faculty/faculty_avatar.dart';
import 'package:srmone_mobile/features/settings/legal_markdown_screen.dart';

void main() {
  group('FacultyAvatar Widget', () {
    testWidgets('renders computed initials when no photo is provided',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FacultyAvatar(
              facultyName: 'Dr. Jane Smith',
              radius: 24,
            ),
          ),
        ),
      );

      // Should remove Dr. and display 'JS'
      expect(find.text('JS'), findsOneWidget);
    });

    testWidgets('renders single initial for single-word name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FacultyAvatar(
              facultyName: 'Prof. Ramesh',
              radius: 20,
            ),
          ),
        ),
      );

      expect(find.text('R'), findsOneWidget);
    });
  });

  group('LegalMarkdownScreen Widget', () {
    testWidgets('displays 100% Local-First Architecture in Privacy Policy',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalMarkdownScreen(
            title: 'Privacy Policy',
            isPrivacyPolicy: true,
          ),
        ),
      );

      expect(find.text('Privacy Policy'), findsWidgets);
      expect(
          find.textContaining('100% Local-First Architecture'), findsOneWidget);
      expect(find.textContaining('Hardware Keystore', skipOffstage: false),
          findsNothing);
    });

    testWidgets('displays Terms of Service content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LegalMarkdownScreen(
            title: 'Terms of Service',
            isPrivacyPolicy: false,
          ),
        ),
      );

      expect(find.text('Terms of Service'), findsWidgets);
      expect(
        find.textContaining('Independent Student Utility'),
        findsOneWidget,
      );
    });
  });

  group('BiometricLockScreen Widget', () {
    testWidgets('displays lock screen or child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BiometricLockScreen(
            child: Text('Dashboard Content'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BiometricLockScreen), findsOneWidget);
    });
  });

  group('AttendanceTrendChart Widget', () {
    testWidgets('displays placeholder when snapshots < 2', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AttendanceTrendChart(snapshots: []),
          ),
        ),
      );

      expect(
        find.textContaining('Attendance trend will appear'),
        findsOneWidget,
      );
    });

    testWidgets('renders chart when 2 or more snapshots exist', (tester) async {
      final snapshots = [
        AttendanceSnapshot(
          id: 1,
          academiaEmail: 'test@srmist.edu.in',
          snapshotDate: '2026-10-01',
          overallPercentage: 80.0,
          weightedPercentage: 81.5,
          subjectsJson: '[]',
          totalClasses: 50,
          attendedClasses: 40,
          createdAt: 1727740800,
        ),
        AttendanceSnapshot(
          id: 2,
          academiaEmail: 'test@srmist.edu.in',
          snapshotDate: '2026-10-02',
          overallPercentage: 82.0,
          weightedPercentage: 83.0,
          subjectsJson: '[]',
          totalClasses: 55,
          attendedClasses: 45,
          createdAt: 1727827200,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceTrendChart(snapshots: snapshots),
          ),
        ),
      );

      expect(find.text('Attendance Trend (30 Days)'), findsOneWidget);
      expect(find.text('75% Min Target'), findsOneWidget);
    });
  });
}
