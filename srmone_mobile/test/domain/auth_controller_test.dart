// test/domain/auth_controller_test.dart
// A failed first sign-in must not leave credentials behind (they would make
// the next launch skip the login screen).

import 'package:drift/native.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:srmone_mobile/core/database/app_database.dart';
import 'package:srmone_mobile/core/security/secure_vault_service.dart';
import 'package:srmone_mobile/domain/services/notification_rule_engine.dart';
import 'package:srmone_mobile/domain/services/session_sync_orchestrator.dart';
import 'package:srmone_mobile/features/auth/auth_controller.dart';

class _MemoryVault extends SecureVaultService {
  final Map<String, String> values = {};

  @override
  Future<void> saveAcademiaCredentials(
      {required String email, required String password}) async {
    values['email'] = email;
    values['password'] = password;
  }

  @override
  Future<String?> getAcademiaEmail() async => values['email'];
  @override
  Future<String?> getAcademiaPassword() async => values['password'];
  @override
  Future<void> saveSpPassword(String password) async => values['sp'] = password;
  @override
  Future<void> clearAll() async => values.clear();
}

class _FakeOrchestrator extends SessionSyncOrchestrator {
  final SyncResult result;

  _FakeOrchestrator(this.result, AppDatabase db, SecureVaultService vault)
      : super(
          db: db,
          vault: vault,
          notifEngine: NotificationRuleEngine(
            db: db,
            notifPlugin: FlutterLocalNotificationsPlugin(),
          ),
        );

  @override
  Future<SyncResult> syncAll({
    bool forceFreshLogin = false,
    SpCaptchaPrompt? onSpCaptcha,
  }) async =>
      result;
}

void main() {
  late AppDatabase db;
  late _MemoryVault vault;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    vault = _MemoryVault();
  });

  tearDown(() => db.close());

  test('failed sign-in clears the saved credentials', () async {
    final controller = AuthController(
      vault: vault,
      orchestrator: _FakeOrchestrator(
        const SyncResult(
          status: SyncStatus.error,
          subjectsUpdated: 0,
          sessionWasRefreshed: false,
          errorMessage: 'Incorrect NetID or password.',
        ),
        db,
        vault,
      ),
    );

    final ok = await controller.login(
        email: 'ab1234', password: 'wrong', spPassword: 'sp');

    expect(ok, isFalse);
    expect(controller.state, isA<AuthError>());
    expect((controller.state as AuthError).message,
        'Incorrect NetID or password.');
    expect(vault.values, isEmpty);
    expect(await vault.hasStoredCredentials(), isFalse);
  });

  test('successful sign-in keeps the credentials', () async {
    final controller = AuthController(
      vault: vault,
      orchestrator: _FakeOrchestrator(
        const SyncResult(
          status: SyncStatus.success,
          subjectsUpdated: 6,
          sessionWasRefreshed: true,
        ),
        db,
        vault,
      ),
    );

    final ok = await controller.login(email: 'ab1234', password: 'right');

    expect(ok, isTrue);
    expect(controller.state, isA<Authenticated>());
    expect(vault.values['email'], 'ab1234@srmist.edu.in');
  });

  test('friendlySyncError hides raw network exceptions', () {
    expect(friendlySyncError(const FormatException('x')),
        contains('could not read'));
  });
}
