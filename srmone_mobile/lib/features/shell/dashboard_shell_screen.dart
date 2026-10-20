// lib/features/shell/dashboard_shell_screen.dart
// Main app shell with bottom navigation bar, top AppBar with NotificationBell,
// and user avatar drawer/action leading to Settings.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/asset_paths.dart';
import '../../core/theme/app_theme.dart';
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

    final c = SrmColors.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        toolbarHeight: 64,
        shape: Border(bottom: BorderSide(color: c.border)),
        title: Row(
          children: [
            Image.asset(AssetPaths.logo, width: 32, height: 32),
            const SizedBox(width: 10),
            Text(
              'SRM ONE',
              style: TextStyle(
                fontFamily: SrmFonts.display,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.4,
                color: c.text,
              ),
            ),
          ],
        ),
        actions: [
          // Reactive Notification Bell
          const NotificationBell(),

          // Settings / Profile Avatar, black with initials as on the web
          IconButton(
            icon: Consumer(
              builder: (context, ref, _) {
                final name =
                    ref.watch(studentProfileProvider).valueOrNull?.name ?? '';
                return Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.hero,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.card, width: 2),
                  ),
                  child: Text(
                    _initials(name),
                    style: TextStyle(
                      color: c.onHero,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          const StudentPortalBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(LucideIcons.house),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.calendarCheck),
              label: 'Attendance',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.clock),
              label: 'Timetable',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.award),
              label: 'Marks',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.calendar),
              label: 'Calendar',
            ),
          ],
        ),
      ),
    );
  }

  /// Up to two initials from [name], like the web app's avatar.
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final s = parts.take(2).map((w) => w[0]).join().toUpperCase();
    return s.isEmpty ? 'S' : s;
  }
}
