// lib/features/shared/app_refresher.dart
// One refresh path for pull-to-refresh and the automatic refresh on launch
// and resume. Academia is synced first and the call returns once attendance
// is saved; the timetable, calendar and Student Portal update in the
// background and the screens pick them up from the database.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/session_sync_orchestrator.dart';
import '../auth/auth_controller.dart';
import '../auth/student_portal_connector.dart';
import 'cached_data_providers.dart';

class AppRefresher {
  final Ref _ref;
  AppRefresher(this._ref);

  /// The automatic refresh skips data newer than this. It reuses the saved
  /// session, so it only signs in again when SRM has expired it.
  static const autoRefreshAfter = Duration(minutes: 30);

  /// Refreshes the signed-in student's data. With [auto] true, does nothing
  /// when the cached attendance is newer than [autoRefreshAfter]. With
  /// [waitForDetails] true (the Timetable and Calendar screens) the timetable
  /// grid and calendar are re-downloaded even if cached today, and the call
  /// waits for them.
  Future<SyncResult?> refresh(
      {bool auto = false, bool waitForDetails = false}) async {
    final email = _ref.read(currentEmailProvider);
    if (email.isEmpty) return null;
    final orchestrator = _ref.read(sessionSyncOrchestratorProvider);
    if (auto) {
      if (orchestrator.isSyncing) return null;
      final last = await orchestrator.lastSyncedAt(email);
      if (last != null && DateTime.now().difference(last) < autoRefreshAfter) {
        return null;
      }
    }
    final result = await orchestrator.syncAll(
      includeStudentPortal: false,
      waitForDetails: waitForDetails,
      forceDetails: waitForDetails,
    );
    if (result.status != SyncStatus.error &&
        await orchestrator.isStudentPortalConfigured()) {
      unawaited(
          _ref.read(studentPortalConnectorProvider.notifier).refreshQuietly());
    }
    return result;
  }
}

final appRefresherProvider = Provider<AppRefresher>(AppRefresher.new);

/// Refreshes in the background when the dashboard first opens and whenever
/// the app comes back to the foreground, if the data is stale.
class AutoRefreshScope extends ConsumerStatefulWidget {
  final Widget child;
  const AutoRefreshScope({super.key, required this.child});

  @override
  ConsumerState<AutoRefreshScope> createState() => _AutoRefreshScopeState();
}

class _AutoRefreshScopeState extends ConsumerState<AutoRefreshScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRefresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoRefresh();
  }

  void _autoRefresh() {
    if (!mounted) return;
    unawaited(ref
        .read(appRefresherProvider)
        .refresh(auto: true)
        .then((_) {}, onError: (Object _) {}));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
