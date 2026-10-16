// lib/features/auth/student_portal_banner.dart
// Slim status strip above the dashboard while the Student Portal connects,
// and a readable error with Retry if it couldn't.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'student_portal_connector.dart';

class StudentPortalBanner extends ConsumerStatefulWidget {
  const StudentPortalBanner({super.key});

  @override
  ConsumerState<StudentPortalBanner> createState() =>
      _StudentPortalBannerState();
}

class _StudentPortalBannerState extends ConsumerState<StudentPortalBanner> {
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SpConnectionState>(studentPortalConnectorProvider, (_, next) {
      _hideTimer?.cancel();
      if (next is SpConnected) {
        // Success needs no action: show it briefly, then get out of the way.
        _hideTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            ref.read(studentPortalConnectorProvider.notifier).dismiss();
          }
        });
      }
    });

    final state = ref.watch(studentPortalConnectorProvider);
    final scheme = Theme.of(context).colorScheme;
    final connector = ref.read(studentPortalConnectorProvider.notifier);

    final (Widget leading, String text, Color bg, List<Widget> actions) =
        switch (state) {
      SpIdle() => (const SizedBox.shrink(), '', Colors.transparent, const []),
      SpConnecting(:final step) => (
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          step.label,
          scheme.surfaceContainerHighest,
          const <Widget>[],
        ),
      SpConnected(:final message) => (
          Icon(Icons.check_circle, size: 18, color: scheme.primary),
          message,
          scheme.surfaceContainerHighest,
          const <Widget>[],
        ),
      SpFailed(:final message) => (
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          message,
          scheme.errorContainer,
          [
            TextButton(
              onPressed: () => unawaited(connector.connect()),
              child: const Text('Retry'),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close, size: 18),
              onPressed: connector.dismiss,
            ),
          ],
        ),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: state is SpIdle
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                key: const ValueKey('sp-banner'),
                width: double.infinity,
                color: bg,
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(text,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ),
    );
  }
}
