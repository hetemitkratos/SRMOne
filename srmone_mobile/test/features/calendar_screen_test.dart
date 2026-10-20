// test/features/calendar_screen_test.dart
// Scrolling the calendar and coming back to a month must not crash: each
// month remembers whether it is expanded, separately from the list's scroll
// offset.

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
  testWidgets('scrolling away from a month and back does not crash',
      (tester) async {
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
    expect(find.text("Jul '26"), findsOneWidget);

    // Expand every month so the list is long, then scroll far down and back.
    for (final name in ["Jul '26", "Aug '26"]) {
      if (find.text(name).evaluate().isNotEmpty) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
    }
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -6000));
    await tester.pumpAndSettle();
    await tester.drag(list, const Offset(0, 12000));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text("Jul '26"), findsOneWidget);
  });
}
