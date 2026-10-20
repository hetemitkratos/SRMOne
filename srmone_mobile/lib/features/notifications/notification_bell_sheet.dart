// lib/features/notifications/notification_bell_sheet.dart
// Reactive notification bell with live unread badge and bottom sheet viewer.
// Fixes legacy manual increment/decrement drift by subscribing to Drift SQLite reactive streams.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../../core/database/app_database.dart';
import '../../main.dart';
import '../auth/auth_controller.dart';

class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final email = authState is Authenticated ? authState.email : '';
    final db = ref.watch(appDatabaseProvider);

    if (email.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<int>(
      stream: db.watchUnreadNotificationCount(email),
      initialData: 0,
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return IconButton(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              '$unreadCount',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            child: const Icon(LucideIcons.bell),
          ),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => NotificationBellSheet(academiaEmail: email),
            );
          },
        );
      },
    );
  }
}

class NotificationBellSheet extends ConsumerWidget {
  final String academiaEmail;

  const NotificationBellSheet({
    super.key,
    required this.academiaEmail,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'low_attendance':
        return LucideIcons.triangleAlert;
      case 'holiday_alert':
        return LucideIcons.calendar;
      case 'welcome':
        return LucideIcons.sparkles;
      default:
        return LucideIcons.bell;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'low_attendance':
        return SrmPalette.terracotta;
      case 'holiday_alert':
        return SrmPalette.lavenderText;
      case 'welcome':
        return SrmPalette.mintText;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Notifications',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await db.markAllNotificationsRead(academiaEmail);
                  },
                  icon: const Icon(LucideIcons.checkCheck, size: 16),
                  label: const Text('Mark all read'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Notification List
          Expanded(
            child: StreamBuilder<List<NotificationsTableData>>(
              stream: db.watchNotifications(academiaEmail),
              builder: (context, snapshot) {
                final notifications = snapshot.data ?? [];

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.bellOff,
                          size: 48,
                          color: SrmPalette.slate500.withAlpha(100),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: SrmPalette.slate500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final dateFormat = DateFormat('MMM d, h:mm a');

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final date = DateTime.fromMillisecondsSinceEpoch(
                      item.createdAt * 1000,
                    );
                    final isUnread = item.read == 0;

                    return Card(
                      elevation: 0,
                      color: isUnread
                          ? theme.colorScheme.primaryContainer.withAlpha(40)
                          : theme.cardColor.withAlpha(150),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isUnread
                              ? theme.colorScheme.primary.withAlpha(80)
                              : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _colorForType(item.type).withAlpha(40),
                          child: Icon(
                            _iconForType(item.type),
                            color: _colorForType(item.type),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight:
                                isUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(item.body),
                            const SizedBox(height: 4),
                            Text(
                              dateFormat.format(date),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: SrmPalette.slate500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
