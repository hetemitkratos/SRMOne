// lib/features/auth/auth_controller.dart
// Riverpod state notifier for authentication state and login actions.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/security/secure_vault_service.dart';
import '../../domain/services/notification_rule_engine.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import '../../main.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  /// The sign-in stage in progress, shown under the spinner.
  final SyncStep step;
  const AuthLoading([this.step = SyncStep.signingIn]);
}

class Authenticated extends AuthState {
  final String email;
  const Authenticated(this.email);
}

class Unauthenticated extends AuthState {
  const Unauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

class AuthController extends StateNotifier<AuthState> {
  final SecureVaultService _vault;
  final SessionSyncOrchestrator _orchestrator;

  AuthController({
    required SecureVaultService vault,
    required SessionSyncOrchestrator orchestrator,
  })  : _vault = vault,
        _orchestrator = orchestrator,
        super(const AuthInitial()) {
    checkInitialAuth();
  }

  Future<void> checkInitialAuth() async {
    try {
      // Read both at once: each secure-storage read is a platform call.
      final (email, password) = await (
        _vault.getAcademiaEmail(),
        _vault.getAcademiaPassword(),
      ).wait;
      if (email != null &&
          email.isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        state = Authenticated(email);
      } else {
        state = const Unauthenticated();
      }
    } catch (_) {
      // Unreadable keystore (e.g. restored from a backup): start signed out
      // rather than hanging on the splash screen.
      state = const Unauthenticated();
    }
  }

  /// Signs in and runs the first Academia sync. Credentials are only kept in
  /// the vault if the sync succeeds, so a wrong password never leaves the app
  /// looking signed in on the next launch.
  ///
  /// The Student Portal is not part of this: once this returns true, call
  /// StudentPortalConnector.connect so its CAPTCHA can't hold up sign-in.
  Future<bool> login({
    required String email,
    required String password,
    String? spPassword,
  }) async {
    state = const AuthLoading();
    try {
      String cleanEmail = email.trim();
      if (!cleanEmail.contains('@')) {
        cleanEmail = '$cleanEmail@srmist.edu.in';
      }

      // Start from a clean vault so stale cookies from another account or a
      // previous failed attempt can't leak into this sign-in.
      await _vault.clearAll();
      await _vault.saveAcademiaCredentials(
        email: cleanEmail,
        password: password,
      );

      if (spPassword != null && spPassword.isNotEmpty) {
        await _vault.saveSpPassword(spPassword);
      }

      final syncResult = await _orchestrator.syncAll(
        forceFreshLogin: true,
        includeStudentPortal: false,
        // Open the dashboard as soon as attendance is saved; the timetable
        // and calendar fill in a moment later.
        waitForDetails: false,
        onProgress: (step) {
          if (mounted) state = AuthLoading(step);
        },
      );

      if (syncResult.status == SyncStatus.error) {
        await _vault.clearAll();
        state = AuthError(syncResult.errorMessage ?? 'Login failed');
        return false;
      }

      state = Authenticated(cleanEmail);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] sign-in failed: ${e.runtimeType}');
      await _vault.clearAll().catchError((_) {});
      state = AuthError(friendlySyncError(e));
      return false;
    }
  }

  Future<void> logout() async {
    await _vault.clearAll();
    state = const Unauthenticated();
  }
}

final secureVaultProvider = Provider<SecureVaultService>((ref) {
  return SecureVaultService();
});

final sessionSyncOrchestratorProvider =
    Provider<SessionSyncOrchestrator>((ref) {
  final vault = ref.watch(secureVaultProvider);
  final db = ref.watch(appDatabaseProvider);
  final notifPlugin = ref.watch(notificationsPluginProvider);

  final notifEngine = NotificationRuleEngine(
    db: db,
    notifPlugin: notifPlugin,
  );

  return SessionSyncOrchestrator(
    db: db,
    vault: vault,
    notifEngine: notifEngine,
  );
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final vault = ref.watch(secureVaultProvider);
  final orchestrator = ref.watch(sessionSyncOrchestratorProvider);

  return AuthController(
    vault: vault,
    orchestrator: orchestrator,
  );
});
