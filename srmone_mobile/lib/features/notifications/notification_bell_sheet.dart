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
              useRootNavigator: true,
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
    final c = SrmColors.of(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(SrmRadii.panel)),
      ),
      child: StreamBuilder<List<NotificationsTableData>>(
        stream: db.watchNotifications(academiaEmail),
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? const [];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontFamily: SrmFonts.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: c.text,
                        ),
                      ),
                    ),
                    if (notifications.isNotEmpty)
                      TextButton.icon(
                        onPressed: () =>
                            db.clearAllNotifications(academiaEmail),
                        icon: const Icon(LucideIcons.checkCheck, size: 16),
                        label: const Text('Clear all'),
                      ),
                  ],
                ),
              ),
              if (notifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                  child: Column(
                    children: [
                      Icon(LucideIcons.bellOff, size: 36, color: c.faint),
                      const SizedBox(height: 12),
                      Text(
                        "You're all caught up",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _tile(c, notifications[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(SrmColors c, NotificationsTableData item) {
    // createdAt is in milliseconds.
    final date = DateTime.fromMillisecondsSinceEpoch(item.createdAt);
    final isUnread = item.read == 0;
    final accent = _colorForType(item.type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnread ? c.track : c.card,
        borderRadius: BorderRadius.circular(SrmRadii.field),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withAlpha(36),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconForType(item.type), size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: c.text,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: SrmPalette.terracotta,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  style: TextStyle(fontSize: 13, height: 1.4, color: c.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('d MMM, h:mm a').format(date),
                  style: TextStyle(fontSize: 11, color: c.faint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
