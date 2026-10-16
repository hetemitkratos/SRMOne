// lib/features/auth/student_portal_connector.dart
// Connects the Student Portal after Academia sign-in has finished, so a slow
// portal or a CAPTCHA never holds the user on the login screen. The state is
// app-wide: the dashboard shows it as a banner while it runs or if it fails.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/root_navigator.dart';
import '../../domain/services/session_sync_orchestrator.dart';
import 'auth_controller.dart';
import 'sp_captcha_bottom_sheet.dart';

sealed class SpConnectionState {
  const SpConnectionState();
}

class SpIdle extends SpConnectionState {
  const SpIdle();
}

class SpConnecting extends SpConnectionState {
  final SyncStep step;
  const SpConnecting(this.step);
}

class SpConnected extends SpConnectionState {
  final String message;
  const SpConnected(this.message);
}

class SpFailed extends SpConnectionState {
  final String message;
  const SpFailed(this.message);
}

class StudentPortalConnector extends StateNotifier<SpConnectionState> {
  final SessionSyncOrchestrator _orchestrator;
  final SpCaptchaPrompt _prompt;

  StudentPortalConnector(this._orchestrator, {SpCaptchaPrompt? prompt})
      : _prompt = prompt ?? promptSpCaptchaFromRoot,
        super(const SpIdle());

  /// Signs in to the Student Portal unless a connection is already running.
  Future<void> connect() async {
    if (state is SpConnecting) return;
    state = const SpConnecting(SyncStep.studentPortal);
    final result = await _orchestrator.connectStudentPortal(
      onSpCaptcha: _prompt,
      onProgress: (step) {
        if (mounted) state = SpConnecting(step);
      },
    );
    if (!mounted) return;
    state = result.connected
        ? SpConnected(result.message)
        : SpFailed(result.message);
  }

  void dismiss() => state = const SpIdle();
}

/// Shows the manual CAPTCHA sheet over whatever screen is open.
Future<String?> promptSpCaptchaFromRoot(Uint8List image) async {
  final context = rootNavigatorKey.currentContext;
  if (context == null || !context.mounted) return null;
  return showSpCaptchaSheet(context, image);
}

final studentPortalConnectorProvider =
    StateNotifierProvider<StudentPortalConnector, SpConnectionState>((ref) {
  return StudentPortalConnector(ref.watch(sessionSyncOrchestratorProvider));
});
