// lib/domain/services/session_sync_orchestrator.dart
// 4-Layer "Zero-Logout" Attendance Auto-Refresh Orchestrator.
// Specification: architecture.md §5, plan.md Phase 3.
//
// Layer 1: Stale-While-Revalidate (SWR) — UI renders cached Drift SQLite stream at 0ms.
// Layer 2: Cache-Busting — GET requests append ?_t=<epoch_ms> and no-cache headers.
// Layer 3: Silent Re-Auth — If session returns 401/403/signin redirect, re-authenticates
//          using SecureVault credentials, updates cookies, and retries seamlessly.
// Layer 4: Dual-Source Reconciliation — Compares Academia and Student Portal hoursConducted.

import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';
import '../../core/network/simple_cookie_jar.dart';
import '../../core/security/secure_vault_service.dart';
import '../../scrapers/academia/academia_client.dart';
import '../../scrapers/student_portal/sp_client.dart';
import 'attendance_planner_math.dart';
import 'notification_rule_engine.dart';

enum SyncStatus { idle, syncing, success, reauthenticated, error }

class SyncResult {
  final SyncStatus status;
  final int subjectsUpdated;
  final bool sessionWasRefreshed;
  final String? errorMessage;

  const SyncResult({
    required this.status,
    required this.subjectsUpdated,
    required this.sessionWasRefreshed,
    this.errorMessage,
  });
}

class SessionSyncOrchestrator {
  final AppDatabase _db;
  final SecureVaultService _vault;
  final NotificationRuleEngine _notifEngine;

  SessionSyncOrchestrator({
    required AppDatabase db,
    required SecureVaultService vault,
    required NotificationRuleEngine notifEngine,
  })  : _db = db,
        _vault = vault,
        _notifEngine = notifEngine;

  /// Main sync method for attendance.
  ///
  /// 1. Reads stored credentials & cookie jar from Hardware Vault.
  /// 2. Fetches fresh attendance via AcademiaClient with cache-busting headers.
  /// 3. If Zoho session expired / invalid, triggers silent re-login with vault credentials.
  /// 4. Optionally reconciles with Student Portal if sp_password or sp_cookies exist.
  /// 5. Upserts updated rows into Drift AttendanceCache and today's AttendanceSnapshot.
  /// 6. Triggers NotificationRuleEngine checks.
  Future<SyncResult> syncAttendance({bool forceFreshLogin = false}) async {
    final email = await _vault.getAcademiaEmail();
    final password = await _vault.getAcademiaPassword();

    if (email == null || email.isEmpty) {
      return const SyncResult(
        status: SyncStatus.error,
        subjectsUpdated: 0,
        sessionWasRefreshed: false,
        errorMessage: 'No authenticated user found in secure vault',
      );
    }

    // Restore or create cookie jar
    final savedCookiesJson = await _vault.getAcademiaCookiesJson();
    final cookieJar = savedCookiesJson != null && savedCookiesJson.isNotEmpty
        ? SimpleCookieJar.fromJson(savedCookiesJson)
        : SimpleCookieJar();

    final academiaClient = AcademiaClient(cookieJar: cookieJar);
    bool sessionRefreshed = false;
    List<AttendanceInput> records = [];

    // Force fresh login requested (e.g. pull-to-refresh "Force Deep Sync")
    if (forceFreshLogin && password != null && password.isNotEmpty) {
      final loginOk = await academiaClient.login(email, password);
      if (loginOk) {
        await _vault.saveAcademiaCookies(cookieJar.toJson());
        sessionRefreshed = true;
      }
    }

    try {
      records = await academiaClient.fetchAttendance();
    } on SessionExpiredException catch (_) {
      // Layer 3: Silent Background Cookie Rotation
      if (password == null || password.isEmpty) {
        return const SyncResult(
          status: SyncStatus.error,
          subjectsUpdated: 0,
          sessionWasRefreshed: false,
          errorMessage:
              'Zoho session expired and no stored password available for re-auth',
        );
      }

      // Re-login silently using vault credentials
      final reauthOk = await academiaClient.login(email, password);
      if (!reauthOk) {
        return const SyncResult(
          status: SyncStatus.error,
          subjectsUpdated: 0,
          sessionWasRefreshed: false,
          errorMessage:
              'Silent re-authentication failed with stored credentials',
        );
      }

      // Save refreshed cookies to vault
      await _vault.saveAcademiaCookies(cookieJar.toJson());
      sessionRefreshed = true;

      // Retry fetching attendance with fresh cookies
      try {
        records = await academiaClient.fetchAttendance();
      } catch (e) {
        return SyncResult(
          status: SyncStatus.error,
          subjectsUpdated: 0,
          sessionWasRefreshed: true,
          errorMessage: 'Fetch failed after re-auth: $e',
        );
      }
    } catch (e) {
      return SyncResult(
        status: SyncStatus.error,
        subjectsUpdated: 0,
        sessionWasRefreshed: false,
        errorMessage: 'Network or parsing error: $e',
      );
    }

    // Save cookie jar state after successful operations
    await _vault.saveAcademiaCookies(cookieJar.toJson());

    // Layer 4: Dual-Source Reconciliation with Student Portal (if configured)
    final spPassword = await _vault.getSpPassword();
    final spSavedCookies = await _vault.getSpCookiesJson();

    if (spPassword != null && spPassword.isNotEmpty || spSavedCookies != null) {
      try {
        final spCookieJar = spSavedCookies != null
            ? SimpleCookieJar.fromJson(spSavedCookies)
            : SimpleCookieJar();
        final spClient = SPClient(cookieJar: spCookieJar);

        final spRecords = await spClient.fetchAttendance();
        if (spRecords.isNotEmpty) {
          records = _reconcileAttendance(records, spRecords);
          await _vault.saveSpCookies(spCookieJar.toJson());
        }
      } catch (_) {
        // Student Portal failure is non-fatal — Academia data is preserved
      }
    }

    // Persist to SQLite (Drift)
    if (records.isNotEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final companions = records.map((r) {
        return AttendanceCacheCompanion(
          academiaEmail: drift.Value(email),
          courseCode: drift.Value(r.courseCode),
          courseTitle: drift.Value(r.courseTitle),
          hoursConducted: drift.Value(r.hoursConducted),
          hoursAbsent: drift.Value(r.hoursAbsent),
          attendancePct: drift.Value(r.attendancePct),
          source: const drift.Value('academia'),
          updatedAt: drift.Value(now),
        );
      }).toList();

      await _db.upsertAttendanceRecords(companions);

      // Upsert daily snapshot
      await _notifEngine.upsertDailySnapshot(email, records);

      // Run low attendance alert checks
      final settings = await _db.watchNotificationSettings(email).first;
      final alertEnabled = settings?.attendanceAlertEnabled == 1;
      final threshold = settings?.attendanceThreshold ?? 75.0;

      await _notifEngine.maybeNotifyLowAttendance(
        email,
        records,
        threshold: threshold,
        alertEnabled: alertEnabled,
      );

      // Check welcome notification rule
      await _notifEngine.maybeNotifyWelcome(email);
    }

    return SyncResult(
      status:
          sessionRefreshed ? SyncStatus.reauthenticated : SyncStatus.success,
      subjectsUpdated: records.length,
      sessionWasRefreshed: sessionRefreshed,
    );
  }

  /// Layer 4: Reconciles records between Academia and Student Portal.
  /// If Student Portal reports higher hoursConducted for a courseCode, uses SP data.
  List<AttendanceInput> _reconcileAttendance(
    List<AttendanceInput> academiaRecords,
    List<AttendanceInput> spRecords,
  ) {
    final spMap = {for (var r in spRecords) r.courseCode.toUpperCase(): r};
    final merged = <AttendanceInput>[];

    for (final acad in academiaRecords) {
      final sp = spMap[acad.courseCode.toUpperCase()];
      if (sp != null && sp.hoursConducted > acad.hoursConducted) {
        // Student Portal has newer attendance counts
        merged.add(
          AttendanceInput(
            courseCode: acad.courseCode,
            courseTitle:
                acad.courseTitle.isNotEmpty ? acad.courseTitle : sp.courseTitle,
            hoursConducted: sp.hoursConducted,
            hoursAbsent: sp.hoursAbsent,
            attendancePct: sp.attendancePct,
          ),
        );
      } else {
        merged.add(acad);
      }
    }

    return merged;
  }
}
