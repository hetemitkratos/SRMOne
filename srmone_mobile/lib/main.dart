// lib/main.dart
// SRMOne Mobile — App Bootstrap
// Initializes Drift DB, WorkManager, flutter_local_notifications, and ProviderScope.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/database/app_database.dart';
import 'app.dart';

// Global DB instance (passed via ProviderScope override)
late final AppDatabase appDatabase;
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// WorkManager background task names
const backgroundSyncTask = 'in.srmone.mobile.attendanceSync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    // Background sync entry point — handled in background_sync_worker.dart
    // This is a lightweight dispatcher; actual work runs in the isolate.
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database
  appDatabase = AppDatabase();

  // Initialize flutter_local_notifications
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit, iOS: darwinInit),
  );

  // Initialize WorkManager for background sync (mobile only)
  if (Platform.isAndroid || Platform.isIOS) {
    await Workmanager().initialize(
      callbackDispatcher,
    );

    // Register periodic background sync (every ~6 hours)
    await Workmanager().registerPeriodicTask(
      backgroundSyncTask,
      backgroundSyncTask,
      frequency: const Duration(hours: 6),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(appDatabase),
        notificationsPluginProvider
            .overrideWithValue(flutterLocalNotificationsPlugin),
      ],
      child: const SrmOneApp(),
    ),
  );
}

// Global providers for DB and notifications plugin
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override appDatabaseProvider in main()');
});

final notificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  throw UnimplementedError('Override notificationsPluginProvider in main()');
});
