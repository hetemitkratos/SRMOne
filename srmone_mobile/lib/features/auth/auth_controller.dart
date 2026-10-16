// lib/features/auth/auth_controller.dart
// Riverpod state notifier for authentication state and login actions.

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
  const AuthLoading();
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
    final hasCreds = await _vault.hasStoredCredentials();
    if (hasCreds) {
      final email = await _vault.getAcademiaEmail();
      state = Authenticated(email ?? '');
    } else {
      state = const Unauthenticated();
    }
  }

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

      await _vault.saveAcademiaCredentials(
        email: cleanEmail,
        password: password,
      );

      if (spPassword != null && spPassword.isNotEmpty) {
        await _vault.saveSpPassword(spPassword);
      }

      final syncResult =
          await _orchestrator.syncAttendance(forceFreshLogin: true);

      if (syncResult.status == SyncStatus.error) {
        state = AuthError(syncResult.errorMessage ?? 'Login failed');
        return false;
      }

      state = Authenticated(cleanEmail);
      return true;
    } catch (e) {
      state = AuthError('Authentication failed: $e');
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
