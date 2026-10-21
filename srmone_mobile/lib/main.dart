// lib/main.dart
// SRMOne Mobile — App Bootstrap
// Initializes Drift DB, WorkManager, flutter_local_notifications, and ProviderScope.

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/database/app_database.dart';
import 'core/diagnostics/error_log.dart';
import 'app.dart';
import 'background/background_sync_worker.dart';

// Global DB instance (passed via ProviderScope override)
late final AppDatabase appDatabase;
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Catch everything uncaught (framework and async) before anything can throw.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorLog.record(details.exception, details.stack,
        context: 'flutter ${details.library ?? ''}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLog.record(error, stack, context: 'uncaught');
    return true;
  };
  await ErrorLog.init().catchError((Object e) {
    debugPrint('[Startup] error log unavailable: $e');
  });

  // Initialize local database
  appDatabase = AppDatabase();

  // Initialize flutter_local_notifications
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  // Permissions are requested after sign-in (see requestNotificationPermission).
  const darwinInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit, iOS: darwinInit),
  );

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

  // Not needed for the first frame, so it runs after runApp.
  unawaited(registerBackgroundSync().catchError((Object e) {
    debugPrint('[Startup] background sync registration failed: $e');
  }));
}

/// Registers the periodic background sync (every ~6 hours, mobile only).
Future<void> registerBackgroundSync() async {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  await Workmanager().initialize(backgroundSyncCallbackDispatcher);
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

/// Stops the periodic background sync (on sign-out).
Future<void> cancelBackgroundSync() async {
  if (!(Platform.isAndroid || Platform.isIOS)) return;
  await Workmanager().cancelByUniqueName(backgroundSyncTask);
}

// Global providers for DB and notifications plugin
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override appDatabaseProvider in main()');
});

final notificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  throw UnimplementedError('Override notificationsPluginProvider in main()');
});

/// Asks for permission to post notifications (Android 13+ runtime permission,
/// iOS alert/badge/sound). Safe to call repeatedly: the OS only prompts once.
Future<void> requestNotificationPermission(
    FlutterLocalNotificationsPlugin plugin) async {
  if (Platform.isAndroid) {
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  } else if (Platform.isIOS) {
    await plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
