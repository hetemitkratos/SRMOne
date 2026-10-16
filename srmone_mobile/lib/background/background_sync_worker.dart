// lib/background/background_sync_worker.dart
// Background worker invoked by WorkManager every ~6 hours.
// Executes headless sync in a separate Dart isolate.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import '../core/database/app_database.dart';
import '../core/security/secure_vault_service.dart';
import '../domain/services/notification_rule_engine.dart';
import '../domain/services/session_sync_orchestrator.dart';

@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final db = AppDatabase();
      final vault = SecureVaultService();
      final notifPlugin = FlutterLocalNotificationsPlugin();

      final notifEngine = NotificationRuleEngine(
        db: db,
        notifPlugin: notifPlugin,
      );

      final orchestrator = SessionSyncOrchestrator(
        db: db,
        vault: vault,
        notifEngine: notifEngine,
      );

      final result = await orchestrator.syncAttendance();
      return result.status != SyncStatus.error;
    } catch (_) {
      return false;
    }
  });
}
