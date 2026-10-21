// lib/background/background_sync_worker.dart
// Background worker invoked by WorkManager every ~6 hours.
// Executes headless sync in a separate Dart isolate.

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import '../core/database/app_database.dart';
import '../core/diagnostics/error_log.dart';
import '../core/security/secure_vault_service.dart';
import '../domain/services/notification_rule_engine.dart';
import '../domain/services/session_sync_orchestrator.dart';

/// WorkManager unique name / task name for the periodic sync.
const backgroundSyncTask = 'in.srmone.mobile.attendanceSync';

@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    AppDatabase? db;
    try {
      await ErrorLog.init();
      // Nothing to refresh, and no alerts, once the student has signed out.
      final vault = SecureVaultService();
      if ((await vault.getAcademiaEmail() ?? '').isEmpty) return true;
      db = AppDatabase();
      final notifPlugin = FlutterLocalNotificationsPlugin();
      await notifPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

      final orchestrator = SessionSyncOrchestrator(
        db: db,
        vault: vault,
        notifEngine: NotificationRuleEngine(db: db, notifPlugin: notifPlugin),
      );

      // No CAPTCHA prompt in the background: Student Portal sign-in only
      // happens if on-device OCR solves it.
      final result = await orchestrator.syncAll();
      // The portal marks finish after the attendance; let them land before
      // the database is closed.
      await orchestrator.spMarksDone;
      return result.status != SyncStatus.error;
    } catch (e, stack) {
      await ErrorLog.record(e, stack, context: 'background sync');
      return false;
    } finally {
      await db?.close();
    }
  });
}
