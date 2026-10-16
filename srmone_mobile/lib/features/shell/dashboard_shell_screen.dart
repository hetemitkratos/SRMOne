// lib/features/shell/dashboard_shell_screen.dart
// Main app shell with bottom navigation bar, top AppBar with NotificationBell,
// and user avatar drawer/action leading to Settings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../main.dart';
import '../auth/student_portal_banner.dart';
import '../notifications/notification_bell_sheet.dart';
import '../shared/cached_data_providers.dart';

class DashboardShellScreen extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardShellScreen({
    super.key,
    required this.navigationShell,
  });

  /// Whether this app run has already asked for notification permission.
  /// Covers users who signed in before the app started asking at sign-in.
  static bool _askedForNotifications = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_askedForNotifications) {
      _askedForNotifications = true;
      final plugin = ref.read(notificationsPluginProvider);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => requestNotificationPermission(plugin),
      );
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Text(
                'S1',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SRM One',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Reactive Notification Bell
          const NotificationBell(),

          // Settings / Profile Avatar
          IconButton(
            icon: Consumer(
              builder: (context, ref, _) {
                final name =
                    ref.watch(studentProfileProvider).valueOrNull?.name ?? 'S';
                final initial = name.isNotEmpty ? name[0].toUpperCase() : 'S';
                return CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2D6A4F),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const StudentPortalBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        indicatorColor: theme.colorScheme.primaryContainer.withAlpha(120),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.layoutDashboard),
            selectedIcon:
                Icon(LucideIcons.layoutDashboard, color: Color(0xFF2D6A4F)),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.checkCheck),
            selectedIcon:
                Icon(LucideIcons.checkCheck, color: Color(0xFF2D6A4F)),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.clock),
            selectedIcon: Icon(LucideIcons.clock, color: Color(0xFF2D6A4F)),
            label: 'Timetable',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.award),
            selectedIcon: Icon(LucideIcons.award, color: Color(0xFF2D6A4F)),
            label: 'Marks',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.calendar),
            selectedIcon: Icon(LucideIcons.calendar, color: Color(0xFF2D6A4F)),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}
