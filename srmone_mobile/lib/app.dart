// lib/app.dart
// SRMOne Material App root with GoRouter, StatefulShellRoute,
// Light/Dark theming, BiometricLockGate, and reactive authentication redirection.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/asset_paths.dart';
import 'core/database/app_database.dart';
import 'core/navigation/root_navigator.dart';
import 'features/attendance/attendance_screen.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/biometric_lock_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/calendar/calendar_screen.dart';
import 'features/marks/marks_screen.dart';
import 'features/overview/overview_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/dashboard_shell_screen.dart';
import 'features/timetable/timetable_screen.dart';
import 'main.dart';

class SrmOneApp extends ConsumerWidget {
  const SrmOneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'SRM One',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
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
            child: DashboardShellScreen(navigationShell: navigationShell),
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
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';
    final db = ref.watch(appDatabaseProvider);

    if (email.isEmpty) return child;

    return StreamBuilder<UserSettingsTableData?>(
      stream: db.watchUserSettings(email),
      builder: (context, snapshot) {
        final biometricEnabled =
            (snapshot.data?.biometricLockEnabled ?? 0) == 1;

        if (biometricEnabled) {
          return BiometricLockScreen(child: child);
        }

        return child;
      },
    );
  }
}

// ─── Splash Screen ─────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(AssetPaths.logo, width: 100, height: 100),
            const SizedBox(height: 24),
            const Text(
              'SRM One',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Local-first academic companion',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFBDE3D5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Themes ───────────────────────────────────────────────────────────────────

ThemeData _lightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2D6A4F),
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
    ),
  );
}

ThemeData _darkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFBDE3D5),
      brightness: Brightness.dark,
      surface: const Color(0xFF0F0F0F),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    cardColor: const Color(0xFF1A1A1A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F0F0F),
      elevation: 0,
      centerTitle: false,
    ),
  );
}
