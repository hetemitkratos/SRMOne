// lib/app.dart
// SRMOne Material App root with GoRouter, StatefulShellRoute,
// Light/Dark theming, BiometricLockGate, and reactive authentication redirection.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/asset_paths.dart';
import 'core/navigation/root_navigator.dart';
import 'core/theme/app_theme.dart';
import 'features/attendance/attendance_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/biometric_lock_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/marks/marks_screen.dart';
import 'features/overview/overview_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shared/app_refresher.dart';
import 'features/shared/cached_data_providers.dart';
import 'features/shell/dashboard_shell_screen.dart';
import 'features/timetable/timetable_screen.dart';

class SrmOneApp extends ConsumerWidget {
  const SrmOneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'SRM One',
      debugShowCheckedModeBanner: false,
      theme: srmLightTheme(),
      darkTheme: srmDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}

// ─── Router Provider ──────────────────────────────────────────────────────────

final _routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _RouterNotifier(ref);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/';

      if (authState is AuthInitial) {
        return isSplash ? null : '/';
      }

      // Stay on the login screen while signing in, so the typed NetID and
      // password survive a failed attempt.
      if (authState is AuthLoading) {
        return isSplash ? '/login' : null;
      }

      if (authState is Unauthenticated || authState is AuthError) {
        return isLoggingIn ? null : '/login';
      }

      if (authState is Authenticated) {
        if (isLoggingIn || isSplash || state.matchedLocation == '/dashboard') {
          return '/overview';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return BiometricLockGate(
            child: AutoRefreshScope(
              child: DashboardShellScreen(navigationShell: navigationShell),
            ),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/overview',
                builder: (context, state) => const OverviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/attendance',
                builder: (context, state) => const AttendanceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/timetable',
                builder: (context, state) => const TimetableScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/marks',
                builder: (context, state) => const MarksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(Ref ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
  }
}

// ─── Biometric Lock Gate ───────────────────────────────────────────────────────

class BiometricLockGate extends ConsumerWidget {
  final Widget child;

  const BiometricLockGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biometricEnabled =
        (ref.watch(userSettingsProvider).valueOrNull?.biometricLockEnabled ??
                0) ==
            1;
    return biometricEnabled ? BiometricLockScreen(child: child) : child;
  }
}

// ─── Splash Screen ─────────────────────────────────────────────────────────────

/// The logo and "SRM ONE" wordmark on cream, as in the web app's header.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final c = SrmColors.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(AssetPaths.logo, width: 88, height: 88),
            const SizedBox(height: 20),
            Text(
              'SRM ONE',
              style: TextStyle(
                fontFamily: SrmFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 30,
                letterSpacing: -0.5,
                color: c.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Local-first academic companion',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: c.text),
            ),
          ],
        ),
      ),
    );
  }
}
