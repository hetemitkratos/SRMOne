// test/features/login_screen_test.dart
// The Student Portal password defaults to the Academia one; switching that
// off asks for it and requires it.

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
import 'package:srmone_mobile/features/auth/login_screen.dart';

class _EmptyVault extends SecureVaultService {
  @override
  Future<String?> getAcademiaEmail() async => null;
  @override
  Future<String?> getAcademiaPassword() async => null;
}

/// Records sign-in attempts instead of signing in.
class _RecordingAuth extends AuthController {
  _RecordingAuth(AppDatabase db, SecureVaultService vault)
      : super(
          vault: vault,
          orchestrator: SessionSyncOrchestrator(
            db: db,
            vault: vault,
            notifEngine: NotificationRuleEngine(
              db: db,
              notifPlugin: FlutterLocalNotificationsPlugin(),
            ),
          ),
        );

  int attempts = 0;

  @override
  Future<bool> login({
    required String email,
    required String password,
    String? spPassword,
  }) async {
    attempts++;
    return false;
  }
}

void main() {
  late AppDatabase db;
  late _RecordingAuth auth;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auth = _RecordingAuth(db, _EmptyVault());
  });

  tearDown(() => db.close());

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [authControllerProvider.overrideWith((ref) => auth)],
      child: const MaterialApp(home: LoginScreen()),
    ));
    await tester.pump();
  }

  testWidgets('the Student Portal uses the Academia password by default',
      (tester) async {
    await pumpLogin(tester);

    final toggle = tester
        .widget<SwitchListTile>(find.byKey(const ValueKey('sp-same-password')));
    expect(toggle.value, isTrue);
    expect(find.text('Student Portal uses the same password'), findsOneWidget);
    expect(find.byKey(const ValueKey('sp-password')), findsNothing);
  });

  testWidgets('switching it off requires a Student Portal password',
      (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const ValueKey('sp-same-password')));
    await tester.pump();
    expect(find.byKey(const ValueKey('sp-password')), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'ab1234');
    await tester.enterText(find.byType(TextFormField).at(1), 'abc123');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Sign In to Dashboard'));
    await tester.pump();

    expect(find.text('Enter your Student Portal password'), findsOneWidget);
    expect(auth.attempts, 0);
  });
}
