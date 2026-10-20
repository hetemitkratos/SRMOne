// test/features/calendar_screen_test.dart
// Moving between months and scrolling the calendar must not crash.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';
import 'package:srmone_mobile/core/security/secure_vault_service.dart';
import 'package:srmone_mobile/domain/services/notification_rule_engine.dart';
import 'package:srmone_mobile/domain/services/session_sync_orchestrator.dart';
import 'package:srmone_mobile/features/auth/auth_controller.dart';
import 'package:srmone_mobile/features/calendar/calendar_screen.dart';
import 'package:srmone_mobile/features/shared/cached_data_providers.dart';

class _SignedInVault extends SecureVaultService {
  @override
  Future<String?> getAcademiaEmail() async => 'ab1234@srmist.edu.in';
  @override
  Future<String?> getAcademiaPassword() async => 'fake-placeholder';
}

List<Map<String, dynamic>> _months() => [
      for (final (i, name) in [
        "Jul '26",
        "Aug '26",
        "Sep '26",
        "Oct '26",
        "Nov '26",
        "Dec '26"
      ].indexed)
        {
          'month': name,
          'days': [
            for (var d = 1; d <= 28; d++)
              {
                'date': '2026-${(7 + i).toString().padLeft(2, '0')}-'
                    '${d.toString().padLeft(2, '0')}',
                'day': 'Mon',
                'event': '',
                'dayOrder': '${d % 5 + 1}',
              },
          ],
        },
    ];

void main() {
  testWidgets('switching months and scrolling does not crash', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final vault = _SignedInVault();
    final orchestrator = SessionSyncOrchestrator(
      db: db,
      vault: vault,
      notifEngine: NotificationRuleEngine(
          db: db, notifPlugin: FlutterLocalNotificationsPlugin()),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
            (ref) => AuthController(vault: vault, orchestrator: orchestrator)),
        calendarMonthsProvider.overrideWith((ref, sem) => _months()),
      ],
      child: const MaterialApp(home: CalendarScreen()),
    ));
    await tester.pumpAndSettle();

    // Pick a month from the pills, step with the arrow, then scroll the
    // page far down and back.
    await tester.tap(find.text("Jul '26").first);
    await tester.pumpAndSettle();
    expect(find.text("Jul '26"), findsNWidgets(2)); // header and pill
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text("Aug '26"), findsNWidgets(2));

    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -6000));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 12000));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text("Aug '26"), findsNWidgets(2));
  });
}
